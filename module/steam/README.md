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
   `ScriptHookVDotNet.log` should list each script as `Started`. SHVDN's console defaults to F4,
   the same key as the Native Trainer; `ConsoleKeyBinding=F8` in `ScriptHookVDotNet.ini` avoids that.
7. **Archive mods (`.oiv`, `update.rpf` edits)**: [OpenRPF](https://www.gta5-mods.com/tools/openrpf-openiv-asi-for-gta-v-enhanced)
   (`OpenRPF.asi` in the game dir) loads whole replacement archives from `mods/`. OpenIV 4.1 can
   read Enhanced's NG-encrypted archives but fails writing them, so patch with a small
   CodeWalker.Core tool instead (source: `~/Games/gta-v-mods/rpfpatch`, built against
   dexyfex/CodeWalker `485d56b`). It runs natively with `dotnet-sdk_8`:
   copy `update/update.rpf` to `mods/update/update.rpf`, then
   `rpfpatch <keysdir> mods/update/update.rpf 'update\update.rpf' patch '<dir in rpf>' <file>...`.
   That switches the archive's TOC to OPEN and writes the files. `<keysdir>` needs a symlink
   literally named `<keysdir>\gta5_enhanced.exe` pointing at `GTA5_Enhanced.exe`. Re-run after
   every game patch, since the copy in `mods/` goes stale.
   - Realistic Driving V's `handling.meta` lacks four Enhanced vehicles (MARBELLA, RHAPSODY,
     SERRANO2, URANUS); merge them in from the game's own file. The merged files are in
     `~/Games/gta-v-mods/rdv-enhanced-merged/content`.
   - Run OpenIV under Proton's wine (`steam-run`) in a Wine virtual desktop. System
     wine-staging's new WoW64 mode makes the 32-bit installer exit silently.

Wine clamps the pointer on the portrait monitor (DP-4), so launch the Rockstar launcher with
DP-3 focused. A launcher that opened on DP-4 works again once it's moved to DP-3 and given a
few seconds.

Saves: `<prefix>/drive_c/users/steamuser/Documents/Rockstar Games/GTAV Enhanced/Profiles/<id>/SGTA500NN`.

## Optional Enhancements

Uncomment in `default.nix` to enable:
- `gamemode`: CPU governor for better gaming performance
- `mangohud`: FPS and performance overlay
- `protonup-qt`: Manage Proton versions for Windows games
