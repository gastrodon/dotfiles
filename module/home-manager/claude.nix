{ pkgs, lib, free-code, ... }:
{
  home.packages = lib.optionals (free-code != null) [
    free-code.packages.${pkgs.system}.dev
  ];

  programs.zsh = {
    shellAliases = lib.optionalAttrs (free-code != null) {
      c = "claude";
    };
  };
}
