{ pkgs, nixpkgs-unstable, ... }:
{
  programs.steam = {
    enable = true;
    # Same glibc as the unstable wivrn runtime, which pressure-vessel loads from the host.
    package =
      (import nixpkgs-unstable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      }).steam.override
        {
          extraArgs = "-pipewire";
          # Steam's 32-bit EGL otherwise loads the 64-bit egl-gbm and fails, so -pipewire capture dies.
          extraEnv.__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS = "/run/opengl-driver/share/egl/egl_external_platform.d:/run/opengl-driver-32/share/egl/egl_external_platform.d";
        };
    extraPackages = [ pkgs.pulseaudio ];
    remotePlay.openFirewall = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamemode.enable = true;
  environment.systemPackages = [ pkgs.mangohud ];

  # In-kernel NT sync for Proton (6.14+); Proton-GE uses /dev/ntsync when present.
  boot.kernelModules = [ "ntsync" ];

  # Keep NVIDIA's shader cache from being evicted, so shaders compile once.
  environment.sessionVariables.__GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
}
