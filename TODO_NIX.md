# TODO_NIX.md - Items that don't map easily to Nix/home-manager

## Challenges and Limitations

### 1. **oh-my-zsh Custom Theme (liner.zsh-theme)**
- **Issue**: Custom oh-my-zsh themes need to be referenced from `~/.config/oh-my-zsh/themes/`
- **Current Status**: The theme file is symlinked, but oh-my-zsh from nixpkgs may need configuration
- **Workaround**: The custom theme is symlinked to `~/.config/oh-my-zsh` and ZSH_CUSTOM is set
- **Action Needed**: Test if the custom theme loads correctly with nixpkgs oh-my-zsh

### 2. **Obsidian Vault**
- **Issue**: The `obsidian-vault` directory contains personal notes/data, not configuration
- **Current Status**: Not included in the flake (should remain a separate git submodule or be ignored)
- **Recommendation**: Keep this separate from dotfiles management

### 3. **DevKitPro Paths**
- **Issue**: Hardcoded paths to `/opt/devkitpro` which is not managed by Nix
- **Current Status**: Environment variables are set in the ZSH config, but the tools aren't installed
- **Action Needed**: Consider packaging DevKitPro for Nix or use Nix overlays

### 4. **NVM (Node Version Manager)**
- **Issue**: NVM is a shell-based tool that downloads and manages Node.js versions
- **Current Status**: Left as-is, expecting manual installation to `~/.config/nvm`
- **Nix Alternative**: Use `pkgs.nodejs` directly or nodePackages from nixpkgs
- **Recommendation**: Consider replacing NVM with Nix's node version management

### 5. **Rust Program Compilation**
- **Issue**: The `link` script compiles `.rs` files on-the-fly
- **Current Status**: `bright.rs` is built using a home-manager activation script
- **Limitation**: Activation scripts run during `home-manager switch`, not automatically when files change
- **Alternative**: Consider creating a proper Nix derivation for the bright program

### 6. **Android SDK Path**
- **Issue**: Hardcoded path to `/opt/android-sdk/platform-tools` in PATH
- **Current Status**: Path is added but SDK is not installed via Nix
- **Action Needed**: Consider using Nix's Android SDK packages or remove if not used

### 7. **Python AWS CLI**
- **Issue**: Using `python -m awscli` instead of the awscli package
- **Current Status**: Left as alias, but Python/virtualenv/awscli not explicitly installed
- **Recommendation**: Add `awscli2` to packages or use `pkgs.python3.withPackages`

### 8. **scrot Command**
- **Issue**: The `scrt` function requires `scrot` package for screenshots
- **Current Status**: Added to packages list
- **Status**: ✓ Resolved

### 9. **VSCodium Extensions**
- **Issue**: `.config/VSCodium/User/extensions.json` lists extensions but doesn't install them
- **Current Status**: File is symlinked, but extensions need manual installation or automation
- **Nix Alternative**: Use home-manager's `programs.vscode` with extensions configuration
- **Action Needed**: Consider porting to programs.vscode with extensions

### 10. **i3 Configuration Scripts**
- **Issue**: i3 has many shell scripts in `.config/i3/scripts/` that may have dependencies
- **Current Status**: Scripts are symlinked but dependencies might not be installed
- **Action Needed**: Audit scripts and ensure all dependencies are in packages list

### 11. **Polybar Scripts**
- **Issue**: Similar to i3, polybar scripts may have dependencies (bt_devices.sh, gen_*.sh)
- **Current Status**: Scripts symlinked but dependencies not verified
- **Action Needed**: Review scripts for required packages (e.g., bluetooth tools, network tools)

### 12. **Auto-discovery of Files**
- **Issue**: Original `link` script auto-discovers all files/directories
- **Current Status**: Flake explicitly lists each directory/file to link
- **Limitation**: New files need to be added to home.nix manually
- **Alternative**: Could create a derivation that discovers files, but that's less declarative

### 13. **Package Availability**
- **Issue**: Some packages from `.config/custom/packages` may not exist in nixpkgs
  - `oh-my-zsh-git` (AUR package) - using `oh-my-zsh` from nixpkgs instead
  - `vscodium-bin` (AUR package) - using `vscodium` from nixpkgs instead
- **Current Status**: Using closest nixpkgs equivalents
- **Action Needed**: Verify these packages work as expected

### 14. **System vs User Configuration**
- **Issue**: Some settings like X11 startup (`.xinitrc`, `.zprofile`) are typically system-level
- **Current Status**: Managed as user files, which works for single-user systems
- **Consideration**: On multi-user systems, some of this might belong in NixOS configuration

### 15. **Stateful Data**
- **Issue**: NVM state, Python virtualenvs, cargo binaries are stateful
- **Current Status**: These are expected to be managed outside of Nix
- **Recommendation**: Document which directories should be preserved across system rebuilds

## Testing Checklist

Before considering this complete, test the following:

- [ ] Run `nix flake check` to validate the flake
- [ ] Run `home-manager switch --flake .#default` to apply configuration
- [ ] Verify all symlinks are created in $HOME
- [ ] Test that ZSH loads with custom theme
- [ ] Verify git configuration is applied
- [ ] Test that the bright program is built and executable
- [ ] Check that i3 configuration loads without errors
- [ ] Verify X11 resources are loaded
- [ ] Test VSCodium compatibility symlinks

## Future Improvements

1. Create proper Nix derivations for custom Rust programs
2. Package the oh-my-zsh custom theme as a Nix package
3. Investigate using home-manager's window manager modules (e.g., `xsession.windowManager.i3`)
4. Replace shell-based tool managers (NVM, etc.) with Nix equivalents
5. Create a more automated discovery mechanism while keeping declarative benefits
6. Consider splitting configuration into multiple modules for better organization
