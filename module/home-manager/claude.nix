{
  pkgs,
  lib,
  free-code,
  obsidian-local-rest-api,
  ...
}:
let
  hosts = import ../hosts.nix;

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

  # Build mcp-obsidian from source
  obsidianLocalRestApiPkg = obsidian-local-rest-api.packages.${pkgs.system}.default;

  # obsidianMcpWrapper = pkgs.writeShellApplication {
  #   name = "obsidian-mcp-server-wrapped";
  #   runtimeInputs = [ obsidianLocalRestApiPkg ];
  #   text = ''
  #     OBSIDIAN_API_KEY="$(< /run/secrets/obsidian/api-key)"
  #     export OBSIDIAN_API_KEY
  #     exec mcp-obsidian "$@"
  #   '';
  # };

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

  claude = free-code.lib.mkClaude pkgs {
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
      # MCP server running inside the `server` host's Minecraft JVM
      # (KubeJS server_scripts, see package/mcp-kubejs). LAN-only, no
      # auth — matches the trust model documented in that package's
      # README.
      minecraft = {
        type = "http";
        url = "http://${hosts.server}:25580/mcp";
      };
      # obsidian = {
      #   command = "${obsidianMcpWrapper}/bin/obsidian-mcp-server-wrapped";
      # };
    };
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
in
{
  home.packages = [
    claude
    claudeEmail
    pkgs.bubblewrap # sandbox runtime
    pkgs.socat # sandbox IPC
  ];

}
