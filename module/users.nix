{
  config,
  pkgs,
  lib,
  ...
}:
let
  githubKeys = builtins.fetchurl {
    url = "https://github.com/gastrodon.keys";
    sha256 = "sha256-o46IPXKvUzgoNgSdLt9j3ThkeJbc6P5HGcFZKHH3Rhw=";
  };
in
{
  programs.zsh.enable = true;

  users.users.${config.identity.username} = {
    isNormalUser = true;
    description = config.identity.name;
    shell = pkgs.zsh;

    extraGroups = [
      "wheel" # Enable sudo
      "networkmanager" # Manage network connections
      "video" # Access video devices (brightness control)
      "audio" # Access audio devices
      "plugdev" # Access USB devices (oscilloscope, etc.)
      "dialout" # Access USB serial devices (Ender 3 printer on /dev/ttyUSB0, etc.)
    ];

    openssh.authorizedKeys.keyFiles = [ githubKeys ];

    # Set a real password with `sudo passwd eva`
    initialPassword = "foobar2000";
  };

  # Root pubkey login for `nixos-rebuild switch --target-host root@<host>`.
  users.users.root.openssh.authorizedKeys.keyFiles = [ githubKeys ];
}
