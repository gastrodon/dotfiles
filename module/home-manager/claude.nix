{
  pkgs,
  ...
}:
let
  hosts = import ../hosts.nix;
  obsidianMcp = import ./obsidian-mcp.nix;

  # Wraps upstream claude-code (nixpkgs) with declarative MCP server and
  # settings config, generated via pkgs.formats.json and passed through
  # --mcp-config / --settings.
  mkClaude =
    {
      settings ? { },
      mcpServers ? { },
      package ? pkgs.claude-code,
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

  # Available GitHub MCP toolsets:
  #   context          - current user and teams
  #   repos            - files, branches, commits, releases, search
  #   issues           - issues CRUD, comments, sub-issues, labels
  #   pull_requests    - PRs CRUD, reviews, merging
  #   users            - user search
  #   actions          - GitHub Actions, CI/CD, job logs
  #   git              - low-level git (repo tree)
  #   notifications    - notification management
  #   orgs             - org search
  #   stargazers       - star/unstar repos
  #   projects         - projects CRUD
  #   discussions      - discussions CRUD
  #   gists            - gists CRUD
  #   labels           - label management
  #   copilot          - copilot issue assignment and reviews
  #   dependabot       - dependabot alerts
  #   code_security    - code scanning alerts
  #   code_quality     - code quality findings
  #   secret_protection     - secret scanning alerts
  #   security_advisories   - global and repo security advisories
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
    runtimeInputs = [ githubMcpPkg ];
    text = ''
      GITHUB_PERSONAL_ACCESS_TOKEN="$(< /run/secrets/github/mcp-token)"
      export GITHUB_PERSONAL_ACCESS_TOKEN
      exec github-mcp-server "$@"
    '';
  };

  # role=admin + group=prod = read-only+safe+destructive, no privileged/sudo. Set explicitly so a rename can't shift the tier.
  sshMcpConfig = (pkgs.formats.toml { }).generate "ssh-mcp.toml" {
    defaults.defaultProfile = "server1";
    profiles = [
      {
        name = "server1";
        host = hosts.server1;
        user = "claude";
        auth = "key";
        keyRef = "/run/secrets/claude-ssh-privkey-local";
        role = "admin";
        group = "prod";
      }
      {
        name = "server2";
        host = hosts.server2;
        user = "claude";
        auth = "key";
        keyRef = "/run/secrets/claude-ssh-privkey-local";
        role = "admin";
        group = "prod";
      }
    ];
  };

  sshMcpWrapper = pkgs.writeShellApplication {
    name = "ssh-mcp-wrapped";
    runtimeInputs = [
      pkgs.nodejs_24
      pkgs.coreutils
    ];
    text = ''
      # ssh-mcp refuses a world-readable config (needs 0600/0700); the store copy is world-readable, so stage a private one.
      cfgdir="''${XDG_RUNTIME_DIR:-/tmp}/ssh-mcp"
      mkdir -p "$cfgdir"
      chmod 700 "$cfgdir"
      install -m600 ${sshMcpConfig} "$cfgdir/config.toml"
      exec npx -y ssh-mcp@2.2.5 -- --config="$cfgdir/config.toml" "$@"
    '';
  };

  awsMcpWrapper = pkgs.writeShellApplication {
    name = "aws-mcp-wrapped";
    runtimeInputs = [
      pkgs.uv
      pkgs.awscli2
    ];
    text = ''
      # Access key id: claude's own (secrets.claude.yaml, in-ring).
      AWS_ACCESS_KEY_ID="$(< /run/secrets/aws/iam_key)"
      export AWS_ACCESS_KEY_ID
      # Secret access key: eva-only (secrets.yaml, out of ring) — into this subprocess env only, never the model.
      AWS_SECRET_ACCESS_KEY="$(< /run/secrets/aws/iam_secret)"
      export AWS_SECRET_ACCESS_KEY
      export AWS_REGION="us-east-1"
      exec uvx awslabs.aws-api-mcp-server@latest "$@"
    '';
  };

  emailMcpWrapper = pkgs.writeShellApplication {
    name = "email-mcp-wrapped";
    runtimeInputs = [ pkgs.nodejs_24 ];
    text = ''
      export MCP_EMAIL_IMAP_HOST="imap.porkbun.com"
      export MCP_EMAIL_IMAP_PORT="993"
      export MCP_EMAIL_IMAP_TLS="true"
      export MCP_EMAIL_SMTP_HOST="smtp.porkbun.com"
      export MCP_EMAIL_SMTP_PORT="587"
      export MCP_EMAIL_SMTP_TLS="false"
      export MCP_EMAIL_SMTP_STARTTLS="true"
      MCP_EMAIL_ADDRESS="$(< /run/secrets/email/address)"
      export MCP_EMAIL_ADDRESS
      MCP_EMAIL_PASSWORD="$(< /run/secrets/email/password)"
      export MCP_EMAIL_PASSWORD
      exec npx -y @codefuturist/email-mcp stdio "$@"
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
    ssh = {
      command = "${sshMcpWrapper}/bin/ssh-mcp-wrapped";
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
  };

  claude = mkClaude {
    inherit mcpServers;
    settings = {
      model = "sonnet";
      # "best" is a valid alias for the top-level `model` field but not for
      # advisorModel: the advisor picker/validator only accepts "opus" or
      # "sonnet" (resolved against opus-4-6/opus-4-7/sonnet-4-6). "opus" is
      # the strongest of the two, preserving the original "best advisor" intent.
      advisorModel = "opus";
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
      autoMemoryEnabled = true;
      autoDreamEnabled = true;
    };
  };

  claudeEmailBase = mkClaude {
    mcpServers = {
      email = {
        command = "${emailMcpWrapper}/bin/email-mcp-wrapped";
      };
    };
    settings = {
      agent = "email-monitor";
    };
  };

  claudeEmail = pkgs.writeShellScriptBin "claude-email" ''
    exec ${claudeEmailBase}/bin/claude "$@"
  '';
in
{
  home.packages = [
    claude
    claudeEmail
  ];
}
