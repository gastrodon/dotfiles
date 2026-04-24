# CLAUDE.md — NixOS Dotfiles

## Critical: "Do X to my system" means edit the Nix config

When asked to install a package, change a setting, add a program, configure a service, or otherwise modify the system — **always make the change declaratively in the Nix config files**. Never run `apt`, `pip`, `npm -g`, shell one-liners, or any ad-hoc system mutation. The right answer is always a `.nix` file edit.

**Never `sudo` anything. Never run `nixos-rebuild switch` or any privileged command. Never attempt to reload i3.**

**Never leave removal comments in source.** When code is removed or migrated, delete it cleanly — no `# deprecated`, `# removed`, `# was here`, `# no longer`, or similar tombstone comments. If the context matters, it belongs in a git commit message, not the source file.

## Testing Changes

```bash
./build
```

Runs `nixos-rebuild build` (no switch, no root required). Emits `./result` which can be inspected to verify the built output. Eva applies changes to her live system herself.

**Always run `./build` after making any Nix config changes.** Fix all errors before presenting the result — never show code that hasn't successfully built. New files must be `git add`-ed before Nix can see them in the flake store.

## Repo Structure

```
configuration.nix            # System entry point. Imports all modules. Defines palette.
hardware-configuration.nix   # Generated hardware config — rarely touch this.
module/
  identity.nix               # username, name, email, SSH key (eva / Eva Harris)
  users.nix                  # User account definition
  x11.nix                    # X11/startx setup (takes palette)
  i3/                        # i3 window manager (takes palette + local packages)
    default.nix              # Enables i3, installs desktop packages, writes config via activation script
    config/                  # i3 config generation (keybinds, layout, floating, exec rules)
    blocks.nix               # i3blocks status bar config
    scripts.nix              # Helper scripts (brightness, lock, etc.)
  steam/                     # Steam + per-game config modules
    games/                   # Individual game configs (factorio, etc.)
  home-manager/              # Home Manager user-level config (runs as eva)
    default.nix              # HM entrypoint: sets extraSpecialArgs, imports all HM modules
    git.nix                  # Git config
    gh.nix                   # GitHub CLI config
    ssh.nix                  # SSH config
    firefox.nix              # Firefox with NUR extensions
    rofi.nix                 # App launcher
    ghostty.nix              # Terminal emulator
    vscodium/                # VSCodium editor + extensions + keybindings + language modules
    zsh/                     # Zsh + oh-my-zsh (liner theme), aliases, initContent
    claude.nix               # claude-code-bun package + `c` alias
package/
  default.nix                # Exports: cmd (shell scripts), sys (Rust), rend (Rust)
  cmd/                       # Shell script packages: fe, scrt, ANSI color helpers
  sys/                       # Rust binary: system info utility
  rend/                      # Rust binary: rendering utility
  obsidian-theme/solarized/  # Custom Obsidian Solarized theme package
```

## Config File Generation

Always generate program config files from Nix attrsets serialized to the target format — never write literal file content or template strings. Use `pkgs.formats.yaml`, `pkgs.formats.json`, `pkgs.formats.toml`, etc.:

```nix
let fmt = pkgs.formats.yaml { };
in builtins.readFile (fmt.generate "config.yaml" {
  some_option = true;
  nested.value = "foo";
})
```

This applies everywhere: `sops.templates`, `home.file`, activation scripts, anywhere a config file is produced.

## Key Patterns

**Solarized Dark palette** — defined in `configuration.nix` and threaded into i3 and home-manager via module args. When adding color-aware modules, accept `{ palette, ... }` and pass it from `configuration.nix`.

**Identity** — user info (username, email, SSH key) lives in `module/identity.nix` and is available as `config.identity` throughout. Use it instead of hardcoding "eva".

**Home Manager modules** — new HM config goes in `module/home-manager/<name>.nix`, then imported in `module/home-manager/default.nix`. HM modules receive `{ identity, palette, claude-code-nix, pkgs, lib, config, ... }`.

**NixOS modules** — new system-level config goes in `module/<name>.nix` (or a subdir with `default.nix`), then imported in `configuration.nix`.

**Custom packages** — local packages are in `package/` and exposed as `local.packages` (list) or `local.cmd`, `local.sys`, `local.rend`. Pass `local` to modules that need custom scripts/binaries.

**NUR** — Firefox extensions use NUR. The overlay is set up in `configuration.nix`.

**claude-code-nix** — fetched as a flake in `configuration.nix`, passed to home-manager, used in `claude.nix`.

## Where to Add Common Things

| Task | File |
|------|------|
| Install a system package | `configuration.nix` → `environment.systemPackages` |
| Install a user package | `module/home-manager/default.nix` → `home.packages` |
| Add a shell alias | `module/home-manager/zsh/default.nix` → `shellAliases` |
| Add a shell function/init | `module/home-manager/zsh/default.nix` → `initContent` |
| Configure a new program | New `module/home-manager/<program>.nix`, import in `default.nix` |
| Add a system service | New `module/<service>.nix`, import in `configuration.nix` |
| Add a custom script | `package/cmd/default.nix` |
| Add an i3 keybind | `module/i3/config/keybinds.nix` |
| Add an i3 autostart | `module/i3/config/exec.nix` |
