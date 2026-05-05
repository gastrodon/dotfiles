{ pkgs, free-code, ... }:
{
  home.packages = [ free-code.packages.${pkgs.system}.dev ];

  programs.zsh.shellAliases.c = "claude";
}
