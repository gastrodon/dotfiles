# passage — age-based password manager, reusing the SOPS age key derived from
# ~/.ssh/id_ed25519. No additional key management needed.
{ config, pkgs, ... }:
{
  home.packages = [ pkgs.passage ];

  home.sessionVariables = {
    PASSAGE_DIR = "${config.home.homeDirectory}/.passage/store";
    PASSAGE_IDENTITIES_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };
}
