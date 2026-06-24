{ pkgs, free-code, ... }:
let
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
        args = [ "stdio" ];
      };
      obsidian = {
        command = "${obsidianMcpWrapper}/bin/obsidian-mcp-server-wrapped";
      };
      email = {
        command = "${emailMcpWrapper}/bin/email-mcp-wrapped";
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
in
{
  home.packages = [
    claude
    pkgs.bubblewrap # sandbox runtime
    pkgs.socat # sandbox IPC
  ];
  programs.zsh.shellAliases.c = "claude";
}
