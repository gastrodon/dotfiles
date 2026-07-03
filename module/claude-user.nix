# Unprivileged `claude` user for the Claude Code agent to SSH into.
# No wheel, no sudo — pubkey lives in ../keys/claude.pub (public by definition).
{ pkgs, lib, ... }:
{
  users.users.claude = {
    isNormalUser = true;
    description = "Claude Code agent";
    shell = pkgs.bash;
    openssh.authorizedKeys.keyFiles = [ ../keys/claude.pub ];
  };

  # Create .ssh directory and set permissions
  system.activationScripts.claude-ssh-setup = lib.stringAfter [ "users" ] ''
    mkdir -p /home/claude/.ssh
    chmod 700 /home/claude/.ssh
    chown claude:users /home/claude/.ssh
  '';
}
