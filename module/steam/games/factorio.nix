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

}
