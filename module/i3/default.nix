{ config, pkgs, ... }:
let
  scripts = import ./scripts.nix { inherit pkgs; };
  blocks = import ./blocks.nix { inherit pkgs; };
  keybinds = import ./keybinds.nix { username = config.identity.username; };
in
{
  services.xserver.windowManager.i3 = {
    enable = true;
    package = pkgs.i3;
    extraPackages = with pkgs; [
      i3status
      i3lock
      i3blocks
    ];
  };

  # Install i3 and essential desktop packages
  environment.systemPackages =
    with pkgs;
    [
      rofi # application finder
      ghostty # terminal emulator

      feh # Wallpaper setter
      scrot # Screenshot utility
      imagemagick # For blur effects in lock script

      pavucontrol # Volume control GUI
      networkmanagerapplet # NetworkManager system tray applet
      xorg.xbacklight # Brightness control

      autotiling # switches tiling directions
      xclip # clipboard
      dunst # notifier
      libnotify # notification daemon
      playerctl # media control
      polkit_gnome # gui authenticator
      dex # xdg-open
      xss-lock # screen locker

      acpi # For battery status
      iproute2 # For network interface info
      alsa-utils # For amixer volume control
    ]
    ++ scripts.scripts
    ++ blocks.scripts;

  # Write i3 config files to user's home directory
  systemd.tmpfiles.rules = [
    "d /home/${config.identity.username}/.config/i3 0755 ${config.identity.username} users - -"
    "f /home/${config.identity.username}/.config/i3/config 0644 ${config.identity.username} users - -"
    "f /home/${config.identity.username}/.config/i3/i3blocks.conf 0644 ${config.identity.username} users - -"
  ];

  environment.etc."i3-config-source".text = keybinds.config;
  environment.etc."i3blocks-config-source".text = blocks.config;

  system.activationScripts.i3config = ''
    cp ${
      config.environment.etc."i3-config-source".source
    } /home/${config.identity.username}/.config/i3/config
    cp ${
      config.environment.etc."i3blocks-config-source".source
    } /home/${config.identity.username}/.config/i3/i3blocks.conf
    chown ${config.identity.username}:users /home/${config.identity.username}/.config/i3/config
    chown ${config.identity.username}:users /home/${config.identity.username}/.config/i3/i3blocks.conf
  '';

  environment.variables = {
    TERMINAL = "ghostty";
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  systemd.user.services.polkit-gnome = {
    description = "Polkit GNOME Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  fonts.packages = with pkgs; [
    fira-code
    fira-code-symbols
    font-awesome
    noto-fonts
    (iosevka-bin.override { variant = "SS04"; })
  ];
}
