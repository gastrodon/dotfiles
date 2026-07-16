{
  pkgs,
  lib,
  ...
}:
let
  hosts = import ../hosts.nix;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
        addKeysToAgent = "yes";
        extraOptions.SetEnv = "TERM=xterm-256color";
      };

      stone.hostname = hosts.stone;
      server.hostname = hosts.server;
      twink.hostname = hosts.twink;
    };
  };

  # programs.ssh writes ~/.ssh/config as a symlink to the nix store (444),
  # which OpenSSH rejects. Replace it with a real copy at 600.
  home.activation.fixSshConfigPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config="$HOME/.ssh/config"
    if [ -L "$config" ]; then
      tmp=$(mktemp)
      cp "$(readlink -f "$config")" "$tmp"
      chmod 600 "$tmp"
      mv "$tmp" "$config"
    fi
  '';

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
