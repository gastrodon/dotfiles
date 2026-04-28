{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Call of Duty: Black Ops 1 (Steam App ID: 42700)
  #
  # Proton: force Proton 5.0 via Steam per-game settings
  #   Library → Tools → install "Proton 5.0" → game Properties → Compatibility → force Proton 5.0
  #   (Proton 5.0 has best D3D9 stability for BO1; newer versions regress on this title)
  # Fallback: Proton-GE is available via extraCompatPackages for non-Steam-shortcut launches
  # Launch options: gamemoderun mangohud %command%
  # Controller: if not detected, toggle Steam Input in game Properties → Controller
}
