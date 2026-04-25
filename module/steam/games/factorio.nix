{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Factorio (Steam App ID: 427520)
  # A game about building and maintaining factories

  # Enable Steam with Factorio support
  programs.steam = {
    enable = true;
    # Ensure Steam library directories are set up
    extraCompatPackages = with pkgs; [
      proton-ge-bin # GE-Proton for better compatibility if needed
    ];
  };

  # Factorio-specific packages
  environment.systemPackages = with pkgs; [
    # Optional: Tools for managing Factorio mods and saves
    # factorio-headless  # Uncomment for dedicated server
  ];

  # Factorio benefits from increased map_count for large factories
  # This helps with performance when factories grow very large
  boot.kernel.sysctl = {
    "vm.max_map_count" = 262144;
  };

  # Ensure proper library paths for Steam games
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  environment.sessionVariables = { };
}
