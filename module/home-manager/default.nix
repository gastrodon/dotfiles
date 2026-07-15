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
          # SSH & Remote Access

          **SSH as**: `claude@<hostname>` — available hosts: ${hostnamesList}

          Uses eva's identity; claude user on remotes has authorized pubkey from `secrets.claude.yaml`.

          **Secrets**: You can access `secrets.claude.yaml` (your keys/credentials). You cannot access `secrets.yaml` (eva-ring only).
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
