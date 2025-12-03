# Local Binaries Nix Module

## Overview
This module manages custom local binaries and scripts that are placed in `.local/bin` and added to the user's PATH.

## Files Encompassed
- `.local/bin/bright.rs` - Rust source code for brightness control utility
- `.local/bin/note-unbuffer` - Shell script for note-taking utilities
- Compiled binaries (like `bright`) that are built from source

## Module Location
`module/local-bin.nix`

## Custom Binaries

### bright (bright.rs)
- Purpose: Display brightness control utility
- Language: Rust
- Compilation: Currently compiled via the `link` script using rustc
- Options: Optimized with -C opt-level=z, -C panic=abort, -C lto

### note-unbuffer
- Purpose: Utility for unbuffered note-taking operations
- Language: Shell script
- Executable: Pre-made script

## Current Build Process
The `link` script currently:
1. Finds all `.rs` files
2. Compiles them with `rustc` using optimization flags
3. Outputs the binary next to the source (removing `.rs` extension)
4. Links the directory to `$HOME/.local/bin`

## Home Manager Integration Points

### For Compiled Binaries (bright)
Multiple approaches possible:
1. Build as a Nix derivation:
   - Create a derivation that builds the Rust code
   - Output to `$HOME/.local/bin` or include in home.packages
2. Use rustPlatform.buildRustPackage:
   - More idiomatic for Rust projects
   - Better dependency management
3. Use home.file with source:
   - Build externally and copy to destination

### For Scripts (note-unbuffer)
- home.file.".local/bin/note-unbuffer".source for direct file placement
- home.file.".local/bin/note-unbuffer".executable = true for permissions
- Or create as a package and add to home.packages

### PATH Management
- Automatically handled if using home.packages
- Manual: home.sessionPath to add `.local/bin` to PATH

## Dependencies
- Rust toolchain (cargo, rustc) for building bright
- For the bright utility:
  - System libraries for display brightness control
  - Possibly xorg or wayland libraries
  - Possibly requires root/setuid for brightness control
- For note-unbuffer:
  - Standard shell utilities
  - Possibly unbuffer command (expect package)

## Notes
- The current build process in `link` script is ad-hoc and should be replaced with proper Nix derivations
- bright.rs uses aggressive optimization flags suggesting size is a concern
- The compiled binary (bright) is in .gitignore, indicating it's meant to be built locally
- Consider whether these utilities should be separate packages or inline derivations
- Scripts may have hardcoded paths that need adjustment for Nix
- Executability must be maintained when deploying scripts
- Consider using Cargo.toml for Rust projects instead of direct rustc compilation
- The bright utility may need special permissions or udev rules for accessing brightness controls
- Dependencies of Rust code need to be properly declared if converting to buildRustPackage
- Consider whether these tools should be system-wide or user-specific
- The current approach mixes build artifacts with source, which Nix separates cleanly
- May want to create a dedicated package directory for local tools
- Consider adding tests for custom utilities
- Documentation should be added for each utility's purpose and usage
- The note-unbuffer script's functionality should be documented for proper porting
