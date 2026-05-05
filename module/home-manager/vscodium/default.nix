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

  openRemoteSshVersion = "0.1.1";
  openRemoteSshSha256 = "1r9h7pi5rhax370r10f5d3h9mafaz2vagbj09rmmr8zn8qs8fdh7";

  defaultBundles =
    with pkgs;
    with vscode-extensions;
    {
      remote-ssh = {
        enable = true;
        extensions = [
          (vscode-utils.buildVscodeMarketplaceExtension {
            mktplcRef = {
              publisher = "jeanp413";
              name = "open-remote-ssh";
              version = openRemoteSshVersion;
            };
            vsix = fetchurl {
              name = "jeanp413-open-remote-ssh.zip";
              url = "https://open-vsx.org/api/jeanp413/open-remote-ssh/${openRemoteSshVersion}/file/jeanp413.open-remote-ssh-${openRemoteSshVersion}.vsix";
              sha256 = openRemoteSshSha256;
            };
          })
        ];
        packages = [ ];
      };
      rich-text = {
        enable = true;
        extensions = [ bierner.markdown-mermaid ];
        packages = [ ];
      };
      nix-ide = {
        enable = true;
        extensions = [ jnoortheen.nix-ide ];
        packages = [ nixfmt-rfc-style ];
      };
      direnv = {
        enable = true;
        extensions = [ mkhl.direnv ];
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
    ./module/go.nix
    ./module/rust.nix
    ./module/terraform.nix
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

    programs.vscode = {
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
