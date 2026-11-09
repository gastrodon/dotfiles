{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamemode.enable = true;
  environment.systemPackages = [ pkgs.mangohud ];

  # In-kernel NT sync for Proton (6.14+); Proton-GE uses /dev/ntsync when present.
  boot.kernelModules = [ "ntsync" ];

  # Keep NVIDIA's shader cache from being evicted, so shaders compile once.
  environment.sessionVariables.__GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
}
