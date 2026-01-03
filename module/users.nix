{ config, pkgs, ... }:
{
  users.users.eva = {
    isNormalUser = true;
    description = "eva";
    packages = with pkgs; [
      bottom
      tldr
      ripgrep
    ];

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
