{ pkgs, lib, ... }:
let
  local = import ../../package { inherit pkgs lib; };

  palette = {
    black = "#073642";
    red = "#dc322f";
    green = "#859900";
    yellow = "#b58900";
    blue = "#268bd2";
    magenta = "#d33682";
    cyan = "#2aa198";
    white = "#eee8d5";

    brightBlack = "#586e75";
    brightRed = "#cb4b16";
    brightGreen = "#586e75";
    brightYellow = "#657b83";
    brightBlue = "#839496";
    brightMagenta = "#6c71c4";
    brightCyan = "#93a1a1";
    brightWhite = "#fdf6e3";

    background = "#002b36";
    foreground = "#839496";
  };
in
{
  imports = [
    ../../module/identity.nix
    ../../module/users.nix
    (import ../../module/x11.nix { inherit palette; })
    (import ../../module/i3 { inherit palette local; })
    ../../module/podman.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.sandbox = "relaxed";

  networking.networkmanager.enable = true;
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim
    curl
    git
    htop
    wget
  ];

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.11";
}
