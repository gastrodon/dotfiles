# System Packages Nix Module

## Overview
This module manages the list of system packages that should be installed. It represents the declarative package manifest for the system.

### modules
note:
- add all packages via home-manager ( as we already do in that directory )
- add just a `<name>/default.nix` if no files specified. We prefer to import directories
---
- module/...
  - theme:
    - provides a selection of themes that we can get colors for
    - theme: {<shell-colors...>, <vscode-theme>, ...}
      maybe more fields to add
    - currently the closest example of this is in x11.nix
      when we implement this, pull the non-gray colors out of there
      and use them to construct the solorized theme
    - pass themes to: vscode, ghostty, zsh

  - extract: add extraction packages like 7z, unzip, unrar, tar, etc
  - polybar:
      - use the packages described below with polybar
        to create a simple top-of-screen status bar. Replaces i3blocks
      - enable systemd.user.services polybar item
- module/home-manager/...
  - dev/default.nix: tie them together
                     provide a function we call with list of langs
                     which returns the package we can pass into vscodium
  - dev/{lang}.nix
    - lang: go, rust, zig, terraform(+nomad, consul, awscli), c(w/gcc), android(+android studio, adb, java, kotlin)
    - appropriate package, vscodium extensions, and settings for {lang}
      if there are already settings ( for example with rust + go ),
      pull them out into the dev/{lang}.nix to modularize it
  - zsh/...
    - default.nix: configure zsh, oh-my-zsh( +extensions, etc )
    - we want to port everything in .zshrc to the most nix idomatic way
      - setting env
      - alias code=codium
      - disable warning on `rm /tmp/exmaple/*`
    - liner.zsh-theme: port over the theme directly, and use it
  - obsidian: basic obsidian setup
              really we want a directory for easy updating later
  - ghostty: add ghostty this way, and configure it.
             See home-manager docs if needed

### custom packages
note:
- all packages have a default.nix ( or whatever file is appropriate ) that package the thing appropriately
- packages should all result in callable binaries, unless otherwise specified
- packages should specify thier build-time dependencies and run-time dependencies
- ideally we want to be able to `nix-shell` these and / or `package.{pkg}.enable = true`


---
- package/...
  - bright
    - brightness controller rust package. We call `bright [0-100]`
    - [TODO] no arg returns currnet brightness `[0-100]`
    - we use aggressive optimization flags,
      mainly because we want it to be a tiny lightweight exec
    - can we use this without sudo since we are in the video group?
  - battery: [TODO] lightweight rust script that returns our battery info
  - render-bars: [TODO] lightweight tool that renders
                 `[0-100]` -> `[ |......... - .........| ]`
  - render-label: [TODO] lightweight tool that renders
                 `label padding` -> `   label   ` according to `padding`
  - render-time: [TODO] renders `padding` -> `   HH:MM   `
  - render-date: [TODO] renders `padding` -> `   DD-MM-YYYY   `
  - polybar/scripts: get rid of these, we will replace them with the above
  - note-unbuffer:
    - [WIP] script that uses copilot to unbuffer obsidian notes
    - [TODO] we want to rewrite this in a not-scripting lang
      with not copilot
  - color:
    - provides shell functions for formatting text in a color
    - currently implemented in zshrc, pull it out into its own package
    - uses the shell-defined colors ( if not already )
  - fe:
    - fc-like tool but uses a constant buffer rather than the last cmd
    - currently implemented in zshrc, pull it out, make it a proper script
    - add opt `-n|--new` that clears the buffer first
  - scrt:
    - another function in zshrc, pull it out, pretty much works ass is
    - it depends on the scrot, xdg-open packages
