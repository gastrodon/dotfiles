# pi-agent — the per-session worker the linear-agent receiver dispatches. This
# is a parameterized Nomad batch job: the receiver POSTs the raw webhook as the
# dispatch payload and passes session_id + a short-lived Linear access token in
# Meta. The task runs the pi coding agent (pi-black routing Anthropic through the
# subscription) headlessly and posts its output back as a Linear `response`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };

  # settings.json for the pi agent. Nix is authoritative — the entrypoint copies
  # this over the volume copy every dispatch, so Eva's tweaks flow through
  # rebuilds. defaultProjectTrust=always is required because -p is non-interactive
  # (no trust prompt) and pi-black is loaded as a package. Model ID is a best
  # guess — verify the real sonnet-5 catalog id with `pi update --models`.
  settingsFile = jsonFormat.generate "pi-settings.json" {
    defaultProvider = "anthropic";
    defaultModel = "claude-sonnet-5";
    defaultThinkingLevel = "high";
    defaultProjectTrust = "always";
    packages = [ "git:github.com/paoloanzn/pi-black@v0.84.1-cc2.1.224.4" ];
  };

  # Unpatched standalone pi. It's a Bun single-exec (glibc-dynamic) — we do NOT
  # autoPatchelf it (patchelf-on-appended-payload breaks Bun single-execs). The
  # interp is the FHS path /lib64/ld-linux-x86-64.so.2; piImage carries glibc,
  # which supplies that loader, so the binary runs unmodified. Keep the tarball
  # layout intact (sibling
  # node_modules + wasm). settings.json rides along so the entrypoint can cp it
  # from the ro mount.
  piPkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "pi-standalone";
    version = "0.84.1";
    src = pkgs.fetchurl {
      url = "https://github.com/earendil-works/pi/releases/download/v0.84.1/pi-linux-x64.tar.gz";
      sha256 = "sha256-VjTX69GCdLY68zcelC80LXS+oBI4lXXB0f8VzmyoDC8=";
    };
    dontPatchELF = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
      cp ${settingsFile} $out/settings.json
    '';
  };

  # From-scratch runtime image, nix-built. It reaches both server boxes through
  # the system closure: the job JSON embeds "docker-archive:${piImage}" and the
  # podman driver's docker-archive: transport ImageLoads that store path — no
  # registry, no push. Carries only the entrypoint's needs: git (clone/push +
  # pi-black's git: install), curl (Linear post), jq (JSON build), bash,
  # coreutils, cacert. pi itself is NOT baked — it rides the /opt/pi bind-mount.
  # glibc supplies /lib64/ld-linux-x86-64.so.2 so the unpatched Bun exec runs here.
  piImage = pkgs.dockerTools.buildLayeredImage {
    name = "pibot-pi";
    tag = "latest";
    contents = [
      pkgs.git
      pkgs.curl
      pkgs.jq
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.cacert
      pkgs.glibc
    ];
    extraCommands = ''
      mkdir -p tmp var/tmp
    '';
    config = {
      Env = [
        "PATH=/bin"
        "LD_LIBRARY_PATH=${pkgs.glibc}/lib"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "SHELL=/bin/bash"
        "HOME=/root"
      ];
      WorkingDir = "/";
    };
  };

  # /opt/pi is the ro nix-store mount (piPkg); /root/.pi/agent is the rw
  # persistent volume (auth.json + pi-black install + trust survive dispatches).
  # Meta lands as NOMAD_META_<key>.
  entrypoint = ''
    set -eu
    export HOME=/root
    mkdir -p "$HOME/.pi/agent"
    cp -f /opt/pi/settings.json "$HOME/.pi/agent/settings.json"

    # GitHub auth for clone/push. The PAT rides in on a ro bind-mount of the sops
    # secret; feed it to git via a credential helper (keeps it out of .gitconfig)
    # and export GH_TOKEN/GITHUB_TOKEN for anything that reads the env. gh is NOT
    # in the base image — API/PR creation via gh needs it added first.
    if [ -f /run/github-pat ]; then
      GH_TOKEN="$(cat /run/github-pat)"
      export GH_TOKEN
      export GITHUB_TOKEN="$GH_TOKEN"
      git config --global credential.helper '!f() { echo username=x-access-token; echo "password=$GH_TOKEN"; }; f'
      git config --global user.name pibot
      git config --global user.email pibot@users.noreply.github.com
    fi

    # Extract the prompt from the raw webhook. The exact field is unconfirmed
    # (Go passes the payload through unparsed) — try promptContext, then the
    # nested form, then fall back to the whole payload so we never send empty.
    # jq -r prints a string bare and an object as compact JSON; .a.b is null-safe.
    prompt=$(jq -r '.promptContext // .agentSession.promptContext // tojson' /local/webhook.json)

    model_args=""
    if [ -n "''${NOMAD_META_model:-}" ]; then model_args="--model ''${NOMAD_META_model}"; fi
    think_args=""
    if [ -n "''${NOMAD_META_thinking:-}" ]; then think_args="--thinking ''${NOMAD_META_thinking}"; fi

    if timeout 30m /opt/pi/pi -p "$prompt" $model_args $think_args >/local/pi-out.txt 2>/local/pi-err.txt; then
      act=response
    else
      act=error
      { echo "pi exited nonzero:"; cat /local/pi-err.txt; } >/local/pi-out.txt
    fi

    # Build the GraphQL body with jq so pi's output (quotes/newlines/backslashes)
    # is correctly JSON-escaped — shell string-building would produce invalid JSON.
    # --rawfile reads pi-out.txt as a string var, so the body is escaped safely.
    jq -n \
      --rawfile body /local/pi-out.txt \
      --arg session "$NOMAD_META_session_id" \
      --arg act "$act" \
      '{query:"mutation($input: AgentActivityCreateInput!) { agentActivityCreate(input: $input) { success } }",variables:{input:{agentSessionId:$session,content:{type:$act,body:$body}}}}' \
      > /local/req.json
    curl -sS -X POST https://api.linear.app/graphql \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $NOMAD_META_access_token" \
      --data @/local/req.json
  '';

  # API JSON shape for POST /v1/jobs — the { Job = {...}; } wrapper is the exact
  # request body. Meta keys declared here must match dispatchNomad exactly or
  # Nomad rejects the dispatch. model/thinking are optional (receiver doesn't send
  # them yet — defaults come from settings.json; per-request routing is future work).
  jobFile = jsonFormat.generate "pi-agent.json" {
    Job = {
      ID = "pi-agent";
      Name = "pi-agent";
      Type = "batch";
      Datacenters = [ "home" ];
      ParameterizedJob = {
        Payload = "optional";
        MetaRequired = [ "session_id" ];
        MetaOptional = [
          "action"
          "access_token"
          "model"
          "thinking"
        ];
      };
      TaskGroups = [
        {
          Name = "pi";
          Count = 1;
          # Pin to the server boxes — only they carry piPkg's store path and the
          # /var/lib/pi-agent/home auth volume (rpi clients are arm64 and lack both).
          Constraints = [
            {
              LTarget = "\${meta.pi_worker}";
              RTarget = "true";
              Operand = "=";
            }
          ];
          Tasks = [
            {
              Name = "pi";
              Driver = "podman";
              Config = {
                image = "docker-archive:${piImage}";
                command = "bash";
                args = [
                  "-c"
                  entrypoint
                ];
                volumes = [
                  "${piPkg}:/opt/pi:ro"
                  "/var/lib/pi-agent/home:/root/.pi/agent"
                  "${config.sops.secrets."github/pat".path}:/run/github-pat:ro"
                ];
              };
              Resources = {
                CPU = 1000;
                MemoryMB = 1024;
              };
              DispatchPayload = {
                File = "webhook.json";
              };
            }
          ];
        }
      ];
    };
  };
in
{
  # GitHub PAT for the worker's clone/push. Server-side secret (servers decrypt
  # secrets.claude.yaml via the claude age key); bind-mounted ro into the job.
  sops.secrets."github/pat" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    mode = "0400";
  };

  # Persistent rw home for the pi container: auth.json, pi-black install, trust,
  # sessions. Survives dispatches; the login command seeds auth.json here once.
  systemd.tmpfiles.rules = [
    "d /var/lib/pi-agent/home 0700 root root -"
  ];

  # Register (idempotent upsert) the job once Nomad has a leader. Cloned from
  # nomad-acl-bootstrap: same retry-until-leader loop, same token handling. Both
  # server boxes run this; a re-register is a no-op.
  systemd.services.pi-agent-register = {
    description = "Register the pi-agent parameterized Nomad batch job";
    after = [ "nomad-acl-bootstrap.service" ];
    requires = [ "nomad-acl-bootstrap.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.curl ];
    environment.NOMAD_ADDR = "http://127.0.0.1:4646";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u
      umask 077
      tmp=$(mktemp)
      trap 'rm -f "$tmp"' EXIT
      tr -d '[:space:]' < ${config.sops.secrets."nomad/bootstrap_token".path} > "$tmp"
      token=$(cat "$tmp")

      for _ in $(seq 1 60); do
        code=$(curl -s -o /dev/null -w '%{http_code}' \
          -H "X-Nomad-Token: $token" \
          -X POST "$NOMAD_ADDR/v1/jobs" \
          --data @${jobFile}) || code=000
        case "$code" in
          200)
            echo "pi-agent job registered"
            exit 0
            ;;
          *)
            sleep 2
            ;;
        esac
      done
      echo "pi-agent registration failed after retries" >&2
      exit 1
    '';
  };
}
