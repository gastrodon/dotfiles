# Steam Module

This module configures Steam and gaming infrastructure on NixOS.

## Features

- Steam with Remote Play and Local Network Game Transfers
- 32-bit library support for game compatibility
- Steam Runtime compatibility tools

## Adding Game-Specific Configurations

To add a game-specific configuration:

1. Create `module/steam/games/your-game.nix`
2. Add your game-specific settings
3. Import it in `module/steam/games/default.nix`

## Example

See `module/steam/games/example-game.nix` for structure.

## GTA V (`games/gta-v.nix`)

Rockstar Games Launcher purchase, run through Lutris (umu-run + GE-Proton). Single-player only:
BattlEye has no Linux support, and Script Hook V closes the game if you go Online. The module
installs `lutris`, `winetricks` and `install-scripthookv`. Everything below is per-user state
that Lutris, the launcher or the game owns, so it stays manual:

1. **Launcher**: in Lutris, search "Grand Theft Auto V" and pick the Rockstar Games Launcher
   installer. If winetricks fails with `MissingRuntimeComponentError`, run Preferences ->
   Updates -> Check for Updates and retry. Prefix: `~/Games/grand-theft-auto-v-2`.
2. **Login and install**: sign in to the launcher, install **GTA V Enhanced** from inside it
   (~96 GB), and accept Cloud Saves.
3. **Script Hook V**: `install-scripthookv "<prefix>/drive_c/Program Files/Rockstar Games/Grand Theft Auto V Enhanced"`
   copies dev-c.com's `bin/` (ScriptHookV.dll, NativeTrainer.asi, args.txt, and both asi
   loaders, `xinput1_4.dll` for Enhanced and `dinput8.dll` for Legacy). After a game patch,
   wait for a new Script Hook V build and re-run it.
4. **DLL overrides**: Wine doesn't load the asi loader from the game dir by itself. In Lutris,
   open Configure -> Runner options -> DLL overrides (or edit
   `~/.local/share/lutris/games/grand-theft-auto-v-*.yml` under `wine.overrides`) and add
   `xinput1_4: n,b` and `dinput8: n,b`.
5. **Check it worked**: launch from Lutris. `asiloader.log` and `ScriptHookV.log` in the game
   dir should show `INIT: Success`, and F4 in Story Mode opens the Native Trainer.
6. **.NET scripts (SHVDN)**: the official SHVDN nightly doesn't target Enhanced; use
   [Script Hook V .NET Enhanced](https://www.gta5-mods.com/tools/script-hook-v-net-enhanced)
   (copy `ScriptHookVDotNet*` and `MinHook.x64.dll` into the game dir, scripts go in `scripts/`).
   It crashes on Proton's Wine-Mono (`ObjectDisposedException` in `ScriptDomain`), so it needs real
   .NET 4.8. With Lutris closed, run `WINEPREFIX=<prefix> winetricks -q dotnet48` using system
   wine (not Proton), then `winetricks -q win10`, because dotnet48 leaves the prefix on Windows 7
   and the launcher refuses to start on 7. Add overrides `MinHook.x64`, `ScriptHookV`,
   `ScriptHookVDotNet2`, `ScriptHookVDotNet3` = `n,b`, and `mscoree: n`. On the first launch
   afterwards, `wineboot` can hang behind `mscorsvw.exe`; killing those processes clears it.
   `ScriptHookVDotNet.log` should list each script as `Started`.

Saves: `<prefix>/drive_c/users/steamuser/Documents/Rockstar Games/GTAV Enhanced/Profiles/<id>/SGTA500NN`.

## Optional Enhancements

Uncomment in `default.nix` to enable:
- `gamemode`: CPU governor for better gaming performance
- `mangohud`: FPS and performance overlay
- `protonup-qt`: Manage Proton versions for Windows games
