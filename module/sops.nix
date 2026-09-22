{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Age key derived from each host's SSH host key — no separate key file to distribute.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # claude's age privkey, planted by ./bootstrap — hosts not listed in .sops.yaml decrypt via this.
  sops.age.keyFile = "/var/lib/sops-nix/bootstrap-key.txt";

  sops.age.generateKey = false;

  sops.defaultSopsFile = lib.mkIf (builtins.pathExists ../secrets.yaml) ../secrets.yaml;

  environment.systemPackages = with pkgs; [
    age
    sops
    ssh-to-age
  ];
}
