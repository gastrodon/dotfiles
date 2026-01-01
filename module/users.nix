# User Configuration
# Defines system users and their basic settings

{ config, pkgs, ... }:

{
  # Define user eva
  users.users.eva = {
    isNormalUser = true;
    description = "eva";
    extraGroups = [ 
      "wheel"          # Enable sudo
      "networkmanager" # Manage network connections
      "video"          # Access video devices (brightness control)
      "audio"          # Access audio devices
    ];
    
    # No password for now - WARNING: This is insecure and should be changed
    # To set a password later, run: passwd eva
    initialPassword = "";
    hashedPassword = null;
  };

  # Allow wheel group to use sudo without password (temporary for initial setup)
  security.sudo.wheelNeedsPassword = false;
}
