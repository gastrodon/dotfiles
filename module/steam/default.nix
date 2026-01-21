{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  environment.systemPackages = with pkgs; [
    steam-run

    # Gaming utilities (optional, add as needed)
    gamemode # CPU governor for gaming
    mangohud # Performance overlay
    protonup-qt # Proton version manager
  ];

  # Optional: Performance tweaks for gaming
  # boot.kernel.sysctl = {
  #   "vm.max_map_count" = 262144;  # Needed for some games
  # };
}
