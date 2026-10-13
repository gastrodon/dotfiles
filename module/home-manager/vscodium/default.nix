{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.vscodium;

  userSettings = import ./settings.nix;
  keybindings = import ./keybindings.nix;
  globalSnippets = (import ./snippets.nix).greek;

  bundleType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this bundle";
      };
      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "VSCode extensions";
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "System packages";
      };
    };
  };

  ext = import ./extension.nix pkgs;

  defaultBundles =
    with pkgs;
    {
      remote-ssh = {
        enable = true;
        extensions = [ (ext "jeanp413.open-remote-ssh") ];
        packages = [ ];
      };
      rich-text = {
        enable = true;
        extensions = [ (ext "bierner.markdown-mermaid") ];
        packages = [ ];
      };
      direnv = {
        enable = true;
        extensions = [ (ext "mkhl.direnv") ];
        packages = [
          direnv
          nix
        ];
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

  options.programs.vscodium = {
    bundles = lib.mkOption {
      type = lib.types.attrsOf bundleType;
      default = { };
      description = ''
        Bundles to install for VSCodium.
        Each bundle can specify extensions and system packages to install.
        These bundles will override default bundles with the same name.
      '';
      example = lib.literalExpression ''
        {
          python = {
            enable = true;
            extensions = [ ms-python.python ];
            packages = [ python3 ];
          };
        }
      '';
    };
  };

  config = {
    home = {
      inherit packages;
    };

    programs.vscodium = {
      enable = true;
      package = pkgs.vscodium;

      profiles.default = {
        inherit
          extensions
          userSettings
          keybindings
          globalSnippets
          ;
      };
    };
  };
}
