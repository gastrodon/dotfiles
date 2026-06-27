{ pkgs, free-code, ... }:
let
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

  githubMcpWrapper = pkgs.writeShellApplication {
    name = "github-mcp-server-wrapped";
    runtimeInputs = [ pkgs.github-mcp-server ];
    text = ''
      GITHUB_PERSONAL_ACCESS_TOKEN="$(< /run/secrets/github/mcp-token)"
      export GITHUB_PERSONAL_ACCESS_TOKEN
      exec github-mcp-server "$@"
    '';
  };

  obsidianMcpWrapper = pkgs.writeShellApplication {
    name = "obsidian-mcp-server-wrapped";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      OBSIDIAN_API_KEY="$(< /run/secrets/obsidian/api-key)"
      export OBSIDIAN_API_KEY
      exec npx -y obsidian-mcp-server "$@"
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
      obsidian = {
        command = "${obsidianMcpWrapper}/bin/obsidian-mcp-server-wrapped";
      };
    };
    settings = {
      model = "claude-sonnet-4-6";
      effortLevel = "medium";
      permissions.defaultMode = "bypassPermissions";
      attribution = {
        commit = "";
        pr = "🌴 Built with love in [South Carolina](https://sc.gov/visitors)";
      };
      sandbox = {
        enabled = true;
        failIfUnavailable = true;
      };
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
      permissions.defaultMode = "bypassPermissions";
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
