{ config, pkgs, lib, ... }:
{
  # Enable Steam
  programs.steam = {
    enable = true;
    
    # Enable Steam Remote Play
    remotePlay.openFirewall = true;
    
    # Enable Steam Local Network Game Transfers
    dedicatedServer.openFirewall = true;
  };

  # Enable 32-bit library support (required for many games)
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  # Additional gaming packages
  environment.systemPackages = with pkgs; [
    # Steam runtime compatibility
    steam-run
    
    # Gaming utilities (optional, add as needed)
    # gamemode        # CPU governor for gaming
    # mangohud        # Performance overlay
    # protonup-qt     # Proton version manager
  ];

  # Optional: Performance tweaks for gaming
  # boot.kernel.sysctl = {
  #   "vm.max_map_count" = 262144;  # Needed for some games
  # };
}
