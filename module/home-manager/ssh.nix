{ config, pkgs, ... }:

{
  home-manager.users.eva = {
    programs.ssh = {
      enable = true;

      matchBlocks = {
        "*" = {
          identityFile = "~/.ssh/id_ed25519";
          identitiesOnly = true;
          addKeysToAgent = "yes";
        };
      };
    };
  };
}
