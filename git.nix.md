# Git Configuration Nix Module

## Overview
This module manages Git version control system configuration, including user identity, editor preferences, behavior settings, and ignore patterns.

## Files Encompassed
- `.gitconfig` - Git configuration with user settings, defaults, and preferences
- `.gitignore` - Global gitignore patterns

## Module Location
`module/git.nix`

## Key Configuration Areas

### User Identity
- Name: eva
- Email: mail@gastrodon.io

### Core Settings
- Editor: vim
- Various behavior and display options

### Init Configuration
- Default branch: main (instead of master)

### Commit Settings
- Verbose: true (show diff when composing commit message)

### Diff Configuration
- `wsErrorHighlight`: context,old (highlight whitespace errors)
- Note: There's a typo in the original config (`wsErrorHightlight` without the second 'l')

### Branch Settings
- Sort: -committerdate (show most recently committed branches first)

### UI Settings
- Color: true (enable colored output)

### Global Gitignore
- Currently ignores: `.local/bin/bright` (compiled binary)

## Home Manager Integration Points
- programs.git.enable for Git installation and basic configuration
- programs.git.userName for user name
- programs.git.userEmail for user email
- programs.git.extraConfig for additional settings (init, commit, diff, branch, color)
- programs.git.ignores for global gitignore patterns
- programs.git.aliases for command aliases (if any are added)

## Dependencies
- git - Version control system
- vim - Text editor (configured as Git editor)
- Optional: diff tools for enhanced diff viewing

## Notes
- User identity is personal and should be parameterized or made configurable
- Email domain is gastrodon.io
- The typo `wsErrorHightlight` should be corrected to `wsErrorHighlight` when porting
- Consider adding more global gitignore patterns for common build artifacts, editor configs, OS files
- The bright binary is currently in gitignore; consider whether it should be built differently
- Verbose commits show full diff which is helpful for reviewing changes before committing
- Default branch setting aligns with GitHub's current default
- Branch sorting by commit date is useful for active development
- Consider adding additional useful aliases in the Nix configuration
- The configuration is minimal, which is good for portability
- Editor choice (vim) should align with the EDITOR environment variable from ZSH module
