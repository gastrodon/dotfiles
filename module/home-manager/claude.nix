{
  pkgs,
  lib,
  free-code,
  desktop,
  ...
}:
let
  hosts = import ../hosts.nix;
  obsidianMcp = import ./obsidian-mcp.nix;

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

  sshMcpWrapper = pkgs.writeShellApplication {
    name = "ssh-mcp-wrapped";
    runtimeInputs = [ pkgs.nodejs_24 ];
    text = ''
      exec npx -y ssh-mcp -- \
        --host=${hosts.server} \
        --user=claude \
        --key=/run/secrets/claude-ssh-privkey-local \
        "$@"
    '';
  };

  awsMcpWrapper = pkgs.writeShellApplication {
    name = "aws-mcp-wrapped";
    runtimeInputs = [
      pkgs.uv
      pkgs.awscli2
    ];
    text = ''
      # Access key id: claude's own secret (secrets.claude.yaml, in-ring).
      AWS_ACCESS_KEY_ID="$(< /run/secrets/aws/iam_key)"
      export AWS_ACCESS_KEY_ID
      # Secret access key: eva-only (secrets.yaml, out of ring). Read at runtime
      # into this subprocess env; never surfaced to the model.
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
    # Obsidian Local REST API plugin's built-in MCP server, over loopback HTTP.
    # The apiKey is a local-only shared value (see obsidian-mcp.nix), not a
    # sops secret, so it can be inlined as a static header here.
    obsidian = {
      type = "http";
      url = obsidianMcp.url;
      headers.Authorization = "Bearer ${obsidianMcp.apiKey}";
    };
  };

  claude = free-code.lib.mkClaude pkgs {
    inherit mcpServers;
    settings = {
      model = {
        default = "opus";
        agent = "haiku";
        plan = "best";
        advisor = "best";
        fallback = {
          claude-fable-5 = [
            "opus-4-8"
            "opus-4-7"
            "opus-4-6"
            "sonnet-5"
          ];
        };
      };
      effortLevel = "low";
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

  claudeEmailBase = free-code.lib.mkClaude pkgs {
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

  # Claude Desktop (Cowork) — reuses the same MCP servers as the CLI but keeps
  # its own settings + config dir so the two can diverge. Only built on hosts
  # that set `desktop.claudeDesktop` (i.e. have /dev/kvm for Cowork's micro-VMs).
  jsonFmt = pkgs.formats.json { };

  desktopSettings = {
    includeCoAuthoredBy = false;
    env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
  };
  desktopSettingsFile = jsonFmt.generate "claude-desktop-settings.json" desktopSettings;
  desktopMcpFile = jsonFmt.generate "claude-desktop-mcp.json" { inherit mcpServers; };

  # The app writes credentials/state into CLAUDE_CONFIG_DIR, so it must be a
  # writable per-user dir, not a store path. On each launch we (re)assert the
  # declarative settings.json and merge our mcpServers into the app-owned
  # .claude.json, preserving whatever state the app has written.
  claudeDesktopLauncher = pkgs.writeShellApplication {
    name = "claude-desktop";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/claude-desktop"
      mkdir -p "$cfg"
      install -m600 ${desktopSettingsFile} "$cfg/settings.json"

      dotclaude="$cfg/.claude.json"
      [ -f "$dotclaude" ] || echo '{}' > "$dotclaude"
      tmp="$(mktemp)"
      jq --slurpfile m ${desktopMcpFile} '.mcpServers = $m[0].mcpServers' "$dotclaude" > "$tmp"
      mv "$tmp" "$dotclaude"
      chmod 600 "$dotclaude"

      export CLAUDE_CONFIG_DIR="$cfg"
      exec ${desktop.claudeDesktop}/bin/claude-desktop "$@"
    '';
  };

  claudeDesktopConfigured = pkgs.symlinkJoin {
    name = "claude-desktop-configured";
    paths = [
      claudeDesktopLauncher
      desktop.claudeDesktop
    ];
    postBuild = ''
      rm -f "$out/bin/claude-desktop"
      ln -s ${claudeDesktopLauncher}/bin/claude-desktop "$out/bin/claude-desktop"

      if [ -e "$out/share/applications/claude-desktop.desktop" ]; then
        rm -f "$out/share/applications/claude-desktop.desktop"
        substitute ${desktop.claudeDesktop}/share/applications/claude-desktop.desktop \
          "$out/share/applications/claude-desktop.desktop" \
          --replace-fail "Exec=${desktop.claudeDesktop}/bin/claude-desktop" "Exec=$out/bin/claude-desktop"
      fi
    '';
  };
in
{
  home.packages = [
    claude
    claudeEmail
    pkgs.bubblewrap # sandbox runtime
    pkgs.socat # sandbox IPC
  ]
  ++ lib.optional (desktop.claudeDesktop != null) claudeDesktopConfigured;

}
