{
  pkgs,
  lib,
  ...
}:
{
  programs.zsh = {
    shellAliases = {
      c = "claude";
    };
  };
}
