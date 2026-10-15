{
  config,
  pkgs,
  lib,
  claude-code-nix,
  ...
}:

let
  cfg = config.programs.zed-editor;

  claude-agent-acp = pkgs.claude-agent-acp.override {
    claude-code = claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  userSettings = import ./settings.nix // {
    agent_servers."Claude Code" = {
      type = "custom";
      command = lib.getExe claude-agent-acp;
      env.CLAUDE_CODE_EXECUTABLE = lib.getExe config.programs.claude.package;
      default_config_options = {
        mode = "auto";
        effort = "low";
      };
    };
  };
  userKeymaps = import ./keymap.nix;
  snippets = (import ./snippets.nix).greek;

  bundleType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this bundle";
      };
      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Zed extension ids";
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "System packages";
      };
    };
  };

  defaultBundles = {
    rich-text = {
      enable = true;
      extensions = [ "mermaid" ];
      packages = [ ];
    };
    theme = {
      enable = true;
      extensions = [ "solarized" ];
      packages = [ ];
    };
  };

  bundles = lib.filterAttrs (n: v: v.enable) (defaultBundles // cfg.bundles);
  extensions = lib.flatten (lib.mapAttrsToList (n: v: v.extensions) bundles);
  packages = lib.flatten (lib.mapAttrsToList (n: v: v.packages) bundles);
in
{
  imports = [
    ./module/bun.nix
    ./module/elm.nix
    ./module/go.nix
    ./module/nix.nix
    ./module/python.nix
    ./module/rust.nix
    ./module/tofu.nix
  ];

  options.programs.zed-editor.bundles = lib.mkOption {
    type = lib.types.attrsOf bundleType;
    default = { };
    description = ''
      Bundles to install for Zed.
      Each bundle can specify extensions and system packages to install.
      These bundles will override default bundles with the same name.
    '';
    example = lib.literalExpression ''
      {
        python = {
          enable = true;
          extensions = [ "ruff" ];
          packages = [ python3 ];
        };
      }
    '';
  };

  config = {
    xdg.configFile."zed/snippets/snippets.json".source =
      (pkgs.formats.json { }).generate "snippets.json"
        snippets;

    programs.zed-editor = {
      enable = true;
      package = pkgs.zed-editor;
      mutableUserSettings = false;
      mutableUserKeymaps = false;
      extraPackages = packages;
      inherit extensions userSettings userKeymaps;
    };
  };
}
