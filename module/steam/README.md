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

## Optional Enhancements

Uncomment in `default.nix` to enable:
- `gamemode`: CPU governor for better gaming performance
- `mangohud`: FPS and performance overlay
- `protonup-qt`: Manage Proton versions for Windows games
