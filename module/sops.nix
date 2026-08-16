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

  system.activationScripts.claude-sops-setup = lib.mkIf (config.users.users ? claude) (
    lib.stringAfter [ "users" ] ''
      mkdir -p /home/claude/.config/sops/age
      chown -R claude:users /home/claude/.config
      chmod 700 /home/claude/.config /home/claude/.config/sops /home/claude/.config/sops/age
    ''
  );

  sops.defaultSopsFile = lib.mkIf (builtins.pathExists ../secrets.yaml) ../secrets.yaml;

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

  # Nomad ACL management token — bootstrapped by server's nomad-acl-bootstrap; claude reads it for CLI auth (NOMAD_TOKEN).
  sops.secrets."nomad/bootstrap_token" = lib.mkIf (config.users.users ? claude) {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    owner = "claude";
    mode = "0400";
  };

  environment.systemPackages = with pkgs; [
    age
    sops
    ssh-to-age
  ];
}
