{ lib, buildNpmPackage }:

# yt-cast-receiver + mpv IPC adapter: makes the box a DIAL/Lounge-API cast
# target for the YouTube/YouTube Music apps (see EVA-186/EVA-187 discovery),
# with mpv doing the actual playback (format selection, hwdec, BT sink).
#
# Compiled via tsc (npmBuildScript = "build") rather than shipping tsx/esbuild
# at runtime — keeps the runtime closure pure JS, which matters for building
# this natively on rpi4b (aarch64) without dragging in esbuild's native
# platform binary.
buildNpmPackage rec {
  pname = "cast-receiver";
  version = "0.0.0";
  src = ./.;

  npmDepsHash = "sha256-Qvj3eecjHoQAgwm/Ay4lRJu/Djo5tOTVF5XP05UKJ4o=";

  npmBuildScript = "build";

  meta = {
    description = "DIAL/YouTube-Lounge cast receiver backed by mpv, for casting from the YouTube/YouTube Music apps";
    mainProgram = "cast-receiver";
    platforms = lib.platforms.linux;
  };
}
