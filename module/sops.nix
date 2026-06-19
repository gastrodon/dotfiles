{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Age key derived from SSH host key — available on all machines without
  # distributing a separate key file.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # User-level age key for encrypting/decrypting secrets locally.
  sops.age.keyFile = "/home/${config.identity.username}/.config/sops/age/keys.txt";

  # sops-nix will create this path if it doesn't exist.
  sops.age.generateKey = false;

  sops.defaultSopsFile = lib.mkIf (builtins.pathExists ../secrets.yaml) ../secrets.yaml;

  system.userActivationScripts.sops-age-key = {
    text = ''
      if [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
        mkdir -p "$HOME/.config/sops/age"
        ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$HOME/.ssh/id_ed25519" \
          > "$HOME/.config/sops/age/keys.txt"
        chmod 600 "$HOME/.config/sops/age/keys.txt"
      fi
    '';
  };

  environment.systemPackages = with pkgs; [
    age
    sops
    ssh-to-age
  ];
}
