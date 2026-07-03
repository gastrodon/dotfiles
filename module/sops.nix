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

  # Claude user sops setup (only on hosts where claude user exists)
  system.activationScripts.claude-sops-setup = lib.mkIf (config.users.users ? claude) (lib.stringAfter [ "users" ] ''
    mkdir -p /home/claude/.config/sops/age
    chown -R claude:users /home/claude/.config
    chmod 700 /home/claude/.config /home/claude/.config/sops /home/claude/.config/sops/age
  '');

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

  sops.secrets."github/mcp-token" = {
    owner = config.identity.username;
  };

  sops.secrets."obsidian/api-key" = {
    owner = config.identity.username;
  };

  sops.secrets."email/address" = {
    owner = config.identity.username;
  };

  sops.secrets."email/password" = {
    owner = config.identity.username;
  };

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
