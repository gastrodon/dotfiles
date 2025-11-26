{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "24.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Install packages
  home.packages = with pkgs; [
    # Core tools
    coreutils
    rustc
    cargo
    rustfmt
    rust-analyzer
    
    # From .config/custom/packages
    autotiling
    curl
    firefox
    gcc
    git
    go
    jq
    less
    lsof
    obsidian
    openssh
    openssl
    openvpn
    ripgrep
    rofi
    sed
    tldr
    unzip
    vim
    wget
    zig
    zip
    zsh
    
    # Fonts
    fira-code
    
    # Window manager
    i3
    i3blocks
    i3lock
    i3status
    
    # Additional tools needed by scripts and functions
    scrot
    xdg-utils  # for xdg-open
    xclip      # for clipboard operations
    
    # Note: vscodium-bin is not in nixpkgs, using vscodium instead
    vscodium
    
    # oh-my-zsh
    oh-my-zsh
  ];

  # ZSH configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    
    initExtra = ''
      # Load oh-my-zsh
      export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh"
      export ZSH_CUSTOM="$HOME/.config/oh-my-zsh"
      ZSH_THEME="liner"
      
      setopt rm_star_silent
      export EDITOR='vim'
      
      # DevKit paths
      export DEVKITPRO='/opt/devkitpro'
      export DEVKITARM='/opt/devkitpro/devkitARM'
      export DEVKITPPC='/opt/devkitpro/devkitPPC'
      
      # Aliases
      alias code="codium"
      alias aws="python -m awscli"
      
      # Functions
      function mkcd () {
        mkdir "$@" && cd "$1"
      }
      
      function mkvenv () {
        mkdir -pv "$1"; python -m virtualenv "$1"; source "$1/bin/activate"
      }
      
      function scrt () {
        disc="$1";
        if [[ "$disc" == "@obsidian" ]]; then 
          shift;
          f="$(date +'%d-%m-%Y-%_H-%M-%S').png";
        
          scrot --select --ignorekeyboard "$HOME/Documents/obsidian-vault/root/scrt/$f";
          xdg-open "obsidian://open?vault=root&file=scrt/$f";
        else
          shift;
          f="$HOME/Pictures/scrot/$disc-$(date +'%d-%m-%Y-%_H-%M-%S').png";
          scrot --select --ignorekeyboard "$f"
          echo "$f";
        fi
      }
      
      FE_SH_SESSION="$(mktemp -d)/fe.sh"
      touch "$FE_SH_SESSION"
      function fe() {
        $=EDITOR $FE_SH_SESSION && eval "$(cat $FE_SH_SESSION)"
      }
      
      function code-remote() {
        r="$1"
        shift
        code --folder-uri vscode-remote://ssh-remote+$r$@
      }
      
      export RM_STAR_SILENT=1
      export DOTNET_CLI_TELEMETRY_OPTOUT=1
      
      # Node Version Manager
      export NVM_DIR="$HOME/.config/nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
      
      # Path extensions
      export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:/opt/android-sdk/platform-tools:$PATH"
      
      source "$ZSH/oh-my-zsh.sh"
      
      # Color functions
      function black() { echo -e "\e[30m$@\e[0m"; }
      function black-bg() { echo -e "\e[40m$@\e[0m"; }
      function red() { echo -e "\e[31m$@\e[0m"; }
      function red-bg() { echo -e "\e[41m$@\e[0m"; }
      function green() { echo -e "\e[32m$@\e[0m"; }
      function green-bg() { echo -e "\e[42m$@\e[0m"; }
      function yellow() { echo -e "\e[33m$@\e[0m"; }
      function yellow-bg() { echo -e "\e[43m$@\e[0m"; }
      function blue() { echo -e "\e[34m$@\e[0m"; }
      function blue-bg() { echo -e "\e[44m$@\e[0m"; }
      function magenta() { echo -e "\e[35m$@\e[0m"; }
      function magenta-bg() { echo -e "\e[45m$@\e[0m"; }
      function cyan() { echo -e "\e[36m$@\e[0m"; }
      function cyan-bg() { echo -e "\e[46m$@\e[0m"; }
      function white() { echo -e "\e[37m$@\e[0m"; }
      function white-bg() { echo -e "\e[47m$@\e[0m"; }
      function bright-black() { echo -e "\e[90m$@\e[0m"; }
      function bright-black-bg() { echo -e "\e[100m$@\e[0m"; }
      function bright-red() { echo -e "\e[91m$@\e[0m"; }
      function bright-red-bg() { echo -e "\e[101m$@\e[0m"; }
      function bright-green() { echo -e "\e[92m$@\e[0m"; }
      function bright-green-bg() { echo -e "\e[102m$@\e[0m"; }
      function bright-yellow() { echo -e "\e[93m$@\e[0m"; }
      function bright-yellow-bg() { echo -e "\e[103m$@\e[0m"; }
      function bright-blue() { echo -e "\e[94m$@\e[0m"; }
      function bright-blue-bg() { echo -e "\e[104m$@\e[0m"; }
      function bright-magenta() { echo -e "\e[95m$@\e[0m"; }
      function bright-magenta-bg() { echo -e "\e[105m$@\e[0m"; }
      function bright-cyan() { echo -e "\e[96m$@\e[0m"; }
      function bright-cyan-bg() { echo -e "\e[106m$@\e[0m"; }
      function bright-white() { echo -e "\e[97m$@\e[0m"; }
      function bright-white-bg() { echo -e "\e[107m$@\e[0m"; }
    '';
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName = "eva";
    userEmail = "mail@gastrodon.io";
    
    extraConfig = {
      core = {
        editor = "vim";
      };
      init = {
        defaultBranch = "main";
      };
      commit = {
        verbose = true;
      };
      diff = {
        wsErrorHightlight = "all";
        wsErrorHighlight = "context,old";
      };
      branch = {
        sort = "-committerdate";
      };
      color = {
        ui = true;
      };
    };
  };

  # Symlink dotfiles to home directory
  home.file = {
    # X11 resources
    ".Xresources".source = ./.Xresources;
    ".xinitrc" = {
      source = ./.xinitrc;
      executable = true;
    };
    ".zprofile" = {
      source = ./.zprofile;
      executable = true;
    };
    
    # Config directories
    ".config/i3".source = ./.config/i3;
    ".config/polybar".source = ./.config/polybar;
    ".config/VSCodium".source = ./.config/VSCodium;
    ".config/gh".source = ./.config/gh;
    ".config/oh-my-zsh".source = ./.config/oh-my-zsh;
    ".config/custom".source = ./.config/custom;
    
    # Local bin directory with scripts
    ".local/bin/note-unbuffer" = {
      source = ./.local/bin/note-unbuffer;
      executable = true;
    };
    
    # Pictures directory
    "Pictures/wall.jpg".source = ./Pictures/wall.jpg;
  };

  # Build the bright Rust program and install it
  home.activation = {
    buildRustPrograms = config.lib.dag.entryAfter ["writeBoundary"] ''
      # Build bright.rs
      if [ -f ${config.home.homeDirectory}/.local/bin/bright.rs ]; then
        $DRY_RUN_CMD ${pkgs.rustc}/bin/rustc \
          -C opt-level=z \
          -C panic=abort \
          -C lto \
          ${config.home.homeDirectory}/.local/bin/bright.rs \
          -o ${config.home.homeDirectory}/.local/bin/bright
        $DRY_RUN_CMD chmod +x ${config.home.homeDirectory}/.local/bin/bright
      fi
    '';
    
    symlinkBright = config.lib.dag.entryAfter ["writeBoundary"] ''
      # Copy bright.rs source to .local/bin
      $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.local/bin
      $DRY_RUN_CMD cp -f ${./.local/bin/bright.rs} ${config.home.homeDirectory}/.local/bin/bright.rs
    '';
    
    createVSCodiumSymlinks = config.lib.dag.entryAfter ["writeBoundary"] ''
      # Create VSCodium symlinks for compatibility
      $DRY_RUN_CMD rm -rf ${config.home.homeDirectory}/.config/VSCodium\ -\ Insiders
      $DRY_RUN_CMD rm -rf ${config.home.homeDirectory}/.config/Code\ -\ OSS
      $DRY_RUN_CMD ln -sf ${config.home.homeDirectory}/.config/VSCodium/ ${config.home.homeDirectory}/.config/VSCodium\ -\ Insiders
      $DRY_RUN_CMD ln -sf ${config.home.homeDirectory}/.config/VSCodium/ ${config.home.homeDirectory}/.config/Code\ -\ OSS
    '';
  };
}
