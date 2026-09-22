{
  palette,
  obsidian-local-rest-api,
  claude-code-nix,
  pi-voice,
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  obsidianMcp = import ./obsidian-mcp.nix;
in

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "old";

    extraSpecialArgs = {
      identity = config.identity;
      hostname = config.networking.hostName;
      desktop = config.desktop;
      inherit
        palette
        obsidian-local-rest-api
        claude-code-nix
        pi-voice
        ;
    };

    users.${config.identity.username} = {
      imports = [
        ./git.nix
        ./gh.nix
        ./ssh.nix
        ./firefox.nix
        ./rofi.nix
        ./vscodium
        ./zsh
        ./ghostty.nix
        ./i3.nix
        ./i3blocks.nix
        ./xresources.nix
        ./passage.nix
      ];

      programs.obsidian = {
        enable = true;
        vaults.notes = {
          target = "notes";
          settings = {
            app = {
              promptDelete = false;
              alwaysUpdateLinks = true;
              newFileLocation = "current";
              attachmentFolderPath = "./";
              pdfExportSettings = {
                includeName = false;
                pageSize = "Letter";
                landscape = false;
                margin = "0";
                downscalePercent = 100;
              };
              useMarkdownLinks = true;
              showLineNumber = false;
              openBehavior = "daily";
            };
            appearance = {
              accentColor = "";
              baseFontSize = 16;
              theme = "obsidian";
              monospaceFontFamily = "Fira Code";
              cssTheme = "Solarized";
            };
            themes = [
              {
                enable = true;
                pkg = pkgs.callPackage ../../package/obsidian-theme/solarized { };
              }
            ];
            communityPlugins = [
              {
                enable = true;
                pkg = pkgs.callPackage ../../package/obsidian-plugin/local-rest-api {
                  obsidianLocalRestApi = obsidian-local-rest-api.packages.${pkgs.stdenv.hostPlatform.system}.default;
                };
                settings = {
                  apiKey = obsidianMcp.apiKey;
                  enableInsecureServer = true;
                  insecurePort = obsidianMcp.port;
                  bindingHost = "127.0.0.1";
                };
              }
              {
                enable = true;
                pkg = pkgs.callPackage ../../package/obsidian-plugin/omnisearch { };
              }
            ];
            corePlugins = [
              "backlink"
              "bookmarks"
              "canvas"
              "command-palette"
              "editor-status"
              "file-explorer"
              "file-recovery"
              "global-search"
              "graph"
              "note-composer"
              "outgoing-link"
              "outline"
              "page-preview"
              "sync"
              "switcher"
              "tag-pane"
              "templates"
              "word-count"
              {
                name = "daily-notes";
                settings = {
                  format = "YYYY-MM-DD";
                  folder = "daily";
                  autorun = true;
                };
              }
            ];
          };
        };
      };

      home.file.".claude/project.md".text = ''
        # Using teams

        When eva says to create a teammate, create a worker, or uses other verbage to imply a persistent or named subagent, she is referring to teammates. Use the CreateTeam and related tools to spawn these agents.

        ## Teammate Naming
        The default naming scheme is to use the names of people, often people in science or other well known individuals. For the task, consider notable individuals. Pick a number of names to assign to your sub-agents. For example if we are working on a coding task, we may use well known computer programmers. If we are doing domain specific work or reverse engineering, we might consider more domain specific individuals or reverse engineers.

        # Your Secrets

        There is no `secrets.claude.yaml` any more, and no `ssh` MCP or claude-owned
        SSH/age keypair — that whole architecture (a shared claude identity that could
        decrypt a dedicated sops file) is gone. What replaced it: each credential you
        use lives in OpenBao, fetched fresh at the moment a tool needs it, never
        decrypted-and-sitting-on-disk the way sops secrets are.

        ## How it actually works
        - `github`, `aws`, and `linear` MCP/CLI credentials are stored in Bao under
          `secret/claude/<service>` (one document per service, several fields each —
          e.g. `secret/claude/aws` has `iam_key` and `iam_secret`).
        - `git push` to Gitea works the same way, via a separate credential helper
          reading `secret/claude/gitea`.
        - Each of these is fetched by logging into an AppRole (`bao-kv-get.nix` for
          the MCP/CLI ones) using a `secret_id` sops decrypts to
          `/run/secrets/bao/<name>_approle_secret_id`, owned by eva. You don't
          normally touch any of this directly — the wrapper scripts do it.
        - There's also a `claude` unix user now (uid isolation, not for remote
          access) with its own Bao identity
          (`/run/secrets/bao/claude_self_approle_secret_id`, file-permission-isolated
          from eva) — currently unused, nothing runs as that user yet.

        ## Secrets boundary
        - You **cannot** decrypt `secrets.yaml` (eva-only) — nothing above requires
          you to; the AppRole `secret_id` files are the only sops secrets you read,
          and they only unlock read access to your own narrow slice of Bao, not
          `secrets.yaml` itself.
        - There is currently no remote-access mechanism (no `ssh` MCP, no claude SSH
          key) — if you need to reach a remote host, ask, don't assume one exists.
      '';

      home.stateVersion = "25.11";

      home.packages = with pkgs; [
        arandr
        bottom
        tldr
        ripgrep
        coreutils
        tmux
      ];

      programs.home-manager.enable = true;
    };
  };
}
