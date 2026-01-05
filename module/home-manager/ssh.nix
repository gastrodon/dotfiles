{
  pkgs,
  lib,
  ...
}:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
        addKeysToAgent = "yes";
      };
    };
  };

  home.activation.generateSshPubKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d ~/.ssh ]; then
      for keyfile in ~/.ssh/id_*; do
        # Check if it's a regular file and doesn't have an extension
        if [ -f "$keyfile" ] && [[ ! "$keyfile" =~ \. ]]; then
          pubkey="$keyfile.pub"
          if [ ! -f "$pubkey" ]; then
            $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -y -f "$keyfile" > "$pubkey"
            $DRY_RUN_CMD chmod 644 "$pubkey"
          fi
        fi
      done
    fi
  '';
}
