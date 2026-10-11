{
  pkgs,
  claude-code-nix,
  ...
}:
let
  obsidianMcp = import ./obsidian-mcp.nix;
  baoKvGet = import ./bao-kv-get.nix { inherit pkgs; };

  mkClaude =
    {
      settings ? { },
      mcpServers ? { },
      package ? claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default,
    }:
    let
      fmt = pkgs.formats.json { };
      mcpConfigFile = fmt.generate "claude-mcp-config.json" { inherit mcpServers; };
      settingsFile = fmt.generate "claude-settings.json" settings;
      extraArgs = pkgs.lib.concatStringsSep " " (
        pkgs.lib.optional (mcpServers != { }) "--mcp-config ${mcpConfigFile}"
        ++ pkgs.lib.optional (settings != { }) "--settings ${settingsFile}"
      );
    in
    pkgs.writeShellScriptBin "claude" ''
      exec ${pkgs.lib.getExe package} ${extraArgs} "$@"
    '';

  # Full toolset name reference: https://github.com/github/github-mcp-server/blob/main/README.md
  githubMcpToolsets = [
    "context"
    "repos"
    "issues"
    "pull_requests"
    "users"
    "actions"
    "git"
    "notifications"
    "orgs"
    "stargazers"
  ];

  githubMcpPkg = pkgs.github-mcp-server.overrideAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "auto-patcher";
      repo = "github-mcp-server";
      rev = "v1.4.0-patch-1";
      hash = "sha256-FfDqM+qHxBc+8CyF+fph3ZY603i0KchXHOMUnWGAPEc=";
    };
    vendorHash = "sha256-J1hC4hdEKLENXLJrsyV41TaJ9+2CuPz5KoIMm2mXvTE=";
  });

  githubMcpWrapper = pkgs.writeShellApplication {
    name = "github-mcp-server-wrapped";
    runtimeInputs = [
      githubMcpPkg
      baoKvGet
    ];
    text = ''
      GITHUB_PERSONAL_ACCESS_TOKEN="$(bao-kv-get claude/github mcp_token)"
      export GITHUB_PERSONAL_ACCESS_TOKEN
      exec github-mcp-server "$@"
    '';
  };

  awsMcpWrapper = pkgs.writeShellApplication {
    name = "aws-mcp-wrapped";
    runtimeInputs = [
      pkgs.uv
      pkgs.awscli2
      baoKvGet
    ];
    text = ''
      AWS_ACCESS_KEY_ID="$(bao-kv-get claude/aws iam_key)"
      export AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY="$(bao-kv-get claude/aws iam_secret)"
      export AWS_SECRET_ACCESS_KEY
      export AWS_REGION="us-east-1"
      # Load-bearing, not caution — removing this silently drops the aws MCP
      # tools with no error anywhere in the session. See wiki: AWS MCP
      # server: the mcp SDK version pin.
      exec uvx --with 'mcp<2.0' awslabs.aws-api-mcp-server@latest "$@"
    '';
  };

  # Lets Claude drive a running Inkscape over D-Bus (github.com/Shriinivas/inkmcp).
  # Pinned to a commit, no tagged releases upstream. Only ONE Inkscape window
  # is ever reachable at a time — see wiki: Inkscape MCP (inkmcp): wiring and
  # the single-instance limit.
  inkmcpSrc = pkgs.fetchFromGitHub {
    owner = "Shriinivas";
    repo = "inkmcp";
    rev = "a46287a17e39a04f940887f2197552f45f3d448c";
    hash = "sha256-MtstM8m+9nM6O8Lb44vIFJfl8YImfnvxX2+GwCyFDog=";
  };

  # inkex/lxml come from Inkscape's own bundled python3Env, not from here — see wiki.
  inkmcpServerEnv = pkgs.python3.withPackages (ps: [
    ps.fastmcp
    ps.mcp
  ]);

  inkscapeMcpWrapper = pkgs.writeShellApplication {
    name = "inkscape-mcp-wrapped";
    runtimeInputs = [
      inkmcpServerEnv
      pkgs.glib # gdbus
    ];
    text = ''
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=''${XDG_RUNTIME_DIR}/bus}"
      exec python3 ${inkmcpSrc}/inkmcp/main.py "$@"
    '';
  };

  mcpServers = {
    github = {
      command = "${githubMcpWrapper}/bin/github-mcp-server-wrapped";
      args = [
        "stdio"
        "--toolsets"
        (builtins.concatStringsSep "," githubMcpToolsets)
      ];
    };
    aws = {
      command = "${awsMcpWrapper}/bin/aws-mcp-wrapped";
    };
    # Obsidian Local REST API MCP over loopback; apiKey is a local-only value (see obsidian-mcp.nix), not a secret, so inlined.
    obsidian = {
      type = "http";
      url = obsidianMcp.url;
      headers.Authorization = "Bearer ${obsidianMcp.apiKey}";
    };
    inkscape = {
      command = "${inkscapeMcpWrapper}/bin/inkscape-mcp-wrapped";
    };
    # piscreen (the wall dashboard on rpi4b): query/apply/preview over plain
    # HTTP on the LAN. The Basic password is the same plaintext stopgap as
    # piscreen.api.plainPassword in the lab/rpi flake (already in the store
    # there), so it is inlined like obsidian's. Moves to a real secret with
    # EVA-560/EVA-563; the phone path is EVA-563.
    piscreen = {
      type = "http";
      url = "http://192.168.0.242:4402/mcp";
      # base64 of "x:piscreen-temp-2026"
      headers.Authorization = "Basic eDpwaXNjcmVlbi10ZW1wLTIwMjY=";
    };
  };

  claude = mkClaude {
    inherit mcpServers;
    settings = {
      model = "sonnet";
      advisorModel = "fable";
      effortLevel = "medium";
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
      };
      attribution = {
        commit = "";
        pr = "🌴 Built with love in [South Carolina](https://sc.gov/visitors)";
      };
      env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      sandbox.enabled = false;

      # A GUARDRAIL, NOT A BOUNDARY -- and the difference matters, so it is
      # written down rather than assumed.
      #
      # The agent runs as the `eva` OS user. sops looks for an age identity at
      # $HOME/.config/sops/age/keys.txt and finds eva's there -- the key that
      # is a recipient of every secrets file. So the agent can decrypt
      # everything, not by permission but by inheriting eva's identity whole.
      # (2026-09-21: it did exactly that, repeatedly, and printed plaintext.)
      #
      # This rule stops `sops` specifically. It does NOT stop anything else
      # that can read that file -- any shell command can cat the key and
      # decrypt by other means -- so it defends against habit and accident,
      # which is what actually went wrong, and against nothing deliberate.
      #
      # The real boundary is a different uid: the `claude` user exists
      # (module/claude-code.nix, no wheel, no sudo) but has no home-manager
      # profile or age identity of its own yet -- running the agent as that
      # user instead of eva isn't wired up, just no longer foreclosed.
      permissions.deny = [
        "Bash(sops:*)"
      ];
      autoMemoryEnabled = true;
      autoDreamEnabled = true;
      # Background jobs edit the real checkout and commit to main, not a worktree.
      worktree.bgIsolation = "none";
    };
  };

  # `claude rc` (remote-control) rejects the --mcp-config/--settings flags that
  # the `claude` wrapper above always injects — it 400s with "Unknown argument"
  # no matter where those flags are placed relative to `rc`. So this calls the
  # bare upstream binary directly instead of going through mkClaude.
  claudeRc = pkgs.writeShellScriptBin "claude-rc" ''
    exec ${pkgs.lib.getExe claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default} rc "$@"
  '';
in
{
  home.packages = [
    claude
    claudeRc
  ];
}
