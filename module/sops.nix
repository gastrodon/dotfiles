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

  environment.systemPackages = with pkgs; [
    age
    sops
    ssh-to-age
  ];
}
