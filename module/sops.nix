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

  # Age key planted by ./bootstrap. Contains claude's age privkey, which is a
  # recipient of secrets.claude.yaml. Hosts that aren't listed in .sops.yaml
  # decrypt via this key.
  sops.age.keyFile = "/var/lib/sops-nix/bootstrap-key.txt";

  # sops-nix will create this path if it doesn't exist.
  sops.age.generateKey = false;

  # Claude user sops setup (only on hosts where claude user exists)
  system.activationScripts.claude-sops-setup = lib.mkIf (config.users.users ? claude) (lib.stringAfter [ "users" ] ''
    mkdir -p /home/claude/.config/sops/age
    chown -R claude:users /home/claude/.config
    chmod 700 /home/claude/.config /home/claude/.config/sops /home/claude/.config/sops/age
  '');

  sops.defaultSopsFile = lib.mkIf (builtins.pathExists ../secrets.yaml) ../secrets.yaml;

  # Claude user secrets (only on hosts where claude user exists)
  sops.secrets."claude/ssh_privkey" = lib.mkIf (config.users.users ? claude) {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    owner = "claude";
    mode = "0600";
  };

  sops.secrets."claude/age_key" = lib.mkIf (config.users.users ? claude) {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    owner = "claude";
    mode = "0600";
    path = "/home/claude/.config/sops/age/keys.txt";
  };

  environment.systemPackages = with pkgs; [
    age
    sops
    ssh-to-age
  ];
}
