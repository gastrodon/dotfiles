{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Call of Duty: Black Ops 2 (Steam App ID: 202970)
  #
  # Proton: GE-Proton — game Properties → Compatibility → enable → select GE-Proton
  #   (D3D11 game; DXVK d3d11 is more mature than d3d9 — expect better perf than BO1)
  # Launch options: MANGOHUD=1 gamemoderun %command%
  # Controller: Steam Input ON for GCN adapter (GCN → virtual Xbox → game sees XInput)
  #   If Xbox controller not detected: toggle Steam Input off (it has native XInput)
}
