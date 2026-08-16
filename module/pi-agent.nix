# pi-agent — the per-session worker the linear-agent receiver dispatches. This
# is a parameterized Nomad batch job: the receiver POSTs the raw webhook as the
# dispatch payload and passes session_id + a short-lived Linear access token in
# Meta. For now the task is a scaffold — it posts a single `response` activity so
# the Linear session closes instead of dangling on the receiver's thought ack.
# Real pi wiring is tracked in EVA-107.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };

  # Runs in docker.io/curlimages/curl with `sh` (entrypoint override verified —
  # the image does not prepend curl). Meta lands as NOMAD_META_<key>. The query
  # is single-quoted so the shell leaves GraphQL's $input literal; only the
  # session id and message interpolate.
  scaffoldScript = ''
    set -eu
    q='mutation($input: AgentActivityCreateInput!) { agentActivityCreate(input: $input) { success } }'
    body="{\"query\":\"$q\",\"variables\":{\"input\":{\"agentSessionId\":\"$NOMAD_META_session_id\",\"content\":{\"type\":\"response\",\"body\":\"pi worker reached this session. Pi is not wired up yet - tracked in EVA-107.\"}}}}"
    curl -sS -X POST https://api.linear.app/graphql \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $NOMAD_META_access_token" \
      --data "$body"
  '';

  # API JSON shape for POST /v1/jobs — the { Job = {...}; } wrapper is the exact
  # request body. Meta keys declared here must match dispatchNomad exactly or
  # Nomad rejects the dispatch.
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
        ];
      };
      TaskGroups = [
        {
          Name = "pi";
          Count = 1;
          Tasks = [
            {
              Name = "pi";
              Driver = "podman";
              Config = {
                image = "docker.io/curlimages/curl:latest";
                command = "sh";
                args = [
                  "-c"
                  scaffoldScript
                ];
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
