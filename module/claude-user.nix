# Unprivileged `claude` user for the Claude Code agent to SSH into.
# No wheel, no sudo — pubkey is decrypted from sops.
{ config, pkgs, lib, ... }
{
  users.users.claude = {
    isNormalUser = true;
    description = "Claude Code agent";
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      (lib.strings.chomp (builtins.readFile config.sops.secrets."claude/ssh_pubkey".path))
    ];
  };

  # Create .ssh directory and set permissions
  system.activationScripts.claude-ssh-setup = lib.stringAfter [ "users" ] ''
    mkdir -p /home/claude/.ssh
    chmod 700 /home/claude/.ssh
    chown claude:users /home/claude/.ssh
  '';
}
