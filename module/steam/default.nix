{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ./games ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    protontricks.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  hardware.graphics.enable32Bit = true;

  boot.kernelModules = [ "xpad" ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 262144;
  };

  programs.gamemode.enable = true;
  programs.gamescope.enable = true;
  environment.systemPackages = with pkgs; [
    protonup-qt
    mangohud
    steam-run
  ];
}
