{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Factorio (Steam App ID: 427520)
  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
}
