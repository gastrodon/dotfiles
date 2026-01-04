{ config, pkgs, ... }:
{
  users.users.${config.identity.username} = {
    isNormalUser = true;
    description = config.identity.name;

    extraGroups = [
      "wheel"          # Enable sudo
      "networkmanager" # Manage network connections
      "video"          # Access video devices (brightness control)
      "audio"          # Access audio devices
    ];

    # Set a real password with `sudo passwd eva`
    initialPassword = "foobar2000";
  };
}
