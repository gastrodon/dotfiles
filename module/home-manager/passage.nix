# passage — age-based password manager.
{ config, pkgs, ... }:
{
  home.packages = [ pkgs.passage ];

  home.sessionVariables = {
    PASSAGE_DIR = "${config.home.homeDirectory}/.passage/store";
    PASSAGE_IDENTITIES_FILE = "${config.home.homeDirectory}/.passage/identities";
  };
}
