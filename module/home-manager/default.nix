{ palette, free-code, obsidian-local-rest-api }:
{ config, pkgs, lib, ... }:
let
  sshModule = import ./ssh.nix { inherit pkgs lib; };
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
      inherit palette free-code obsidian-local-rest-api;
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
        ./3d-print.nix
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

      home.file.".claude/project.md".text =
        let
          hostnames = builtins.sort builtins.lessThan (builtins.filter (n: n != "*") (builtins.attrNames sshModule.programs.ssh.matchBlocks));
          hostnamesList = builtins.concatStringsSep ", " (map (h: "`${h}`") hostnames);
        in
        ''
          # Your Keys, Identity & Remote Access

          ## Reaching machines (hosts: ${hostnamesList})
          - **`ssh` MCP** — connects to `server` as the `claude` user, using your own SSH key. Prefer this for remote work; it wields the key for you.
          - **Shell `ssh claude@<host>`** — runs as eva, authenticates with eva's identity.

          ## Your SSH keypair (the `claude` user's own key)
          - **Public**: `keys/claude.pub` in the dotfiles repo — this is what authorizes `claude@server` / `claude@stone`.
          - **Private**: canonically `secrets.claude.yaml` → `claude/ssh_privkey` (yours to decrypt — in-ring). Deployed for the claude system user at `/run/secrets/claude/ssh_privkey` (where that user exists). You rarely need the raw key: the `ssh` MCP already uses it.
          - **When to use**: to operate on a remote box as the `claude` user — normally just call the `ssh` MCP.

          ## Your age key (`age1hwzgc327phsapeqf6q3jtc86pu3pk40pk36zejev0lplhfz5e5xqk7mmec`)
          - Stored at `secrets.claude.yaml` → `claude/age_key`; deployed to the claude system user at `/home/claude/.config/sops/age/keys.txt`.
          - **Purpose / when to use**: it lets the *claude system user* decrypt `secrets.claude.yaml` locally on a remote host. When you run as eva, eva's age key decrypts that file instead — so the claude age key is the remote/system-user side, not something you invoke directly here.

          ## AWS (`aws` MCP)
          - Gives you AWS API access (IAM + resources) via a dedicated IAM user. Your access key **id** is your own (`secrets.claude.yaml` → `aws/iam_key`); the **secret** access key is eva-only and injected into the MCP at runtime — you never see it.
          - Trust-but-verify: real changes land in the account, so act deliberately.

          ## Secrets boundary (eva-ring)
          - You **can** decrypt `secrets.claude.yaml` — your own keys/credentials (SSH key, age key, AWS key id, etc.).
          - You **cannot** decrypt `secrets.yaml` (eva-only). Never use any key above to reach it.
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
