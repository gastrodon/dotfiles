# passage — age-based password manager, reusing the SOPS age key derived from
# ~/.ssh/id_ed25519. No additional key management needed.
{ pkgs, ... }:
{
  home.packages = [ pkgs.passage ];

  home.sessionVariables = {
    PASSAGE_DIR = "$HOME/.passage/store";
    PASSAGE_IDENTITIES_FILE = "$HOME/.config/sops/age/keys.txt";
  };
}
