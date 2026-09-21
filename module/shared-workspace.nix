# A working tree both the human and the agent can reach.
#
# WHY THIS EXISTS. The agent runs as an OS user. If that user is `eva`, it
# inherits eva's whole identity -- including the age key at
# ~/.config/sops/age/keys.txt, which is a recipient of every secrets file, so
# the agent can decrypt everything by default rather than by decision. The
# only real boundary is a different uid.
#
# But /home/eva is 0700, so an agent running as `claude` cannot traverse into
# it at all, and the files inside are 0644 eva:users -- readable at best,
# never writable. Loosening /home/eva to 0750 would trade the whole home
# directory's privacy for shared access to a few repos, which is the wrong
# trade: what wants sharing is the CODE, not the home.
#
# So: a directory outside both homes, group-owned by a group both users are
# in, setgid so new entries inherit that group. /home/eva stays 0700 and the
# age key stays genuinely unreachable.
{
  config,
  lib,
  ...
}:
{
  # THE PART SETGID DOES NOT SOLVE, stated so it is not discovered later.
  #
  # setgid fixes group OWNERSHIP of new files. It does not fix their MODE: a
  # file created under the default umask of 022 comes out 0644, so the group
  # that now owns it still cannot write it. Two ways to close that, neither
  # imposed here because both have costs:
  #
  #   umask 002 for both users -- correct everywhere, but it also makes files
  #   group-writable OUTSIDE this directory, a broader change than the problem
  #   needs.
  #
  #   git config --global core.sharedRepository=group -- targeted, since the
  #   contents here are git repos and git then creates its own files 0664.
  #   Does nothing for files written by editors or build tools.
  #
  # Start with the git setting; reach for the umask only if something outside
  # git turns out to need it.
  config = lib.mkMerge [
    {
      users.groups.devs = { };
      users.users.${config.identity.username}.extraGroups = [ "devs" ];

      systemd.tmpfiles.rules = [
        # 2775: setgid + rwxrwxr-x. The setgid bit is the load-bearing part --
        # it makes everything created below inherit group `devs` instead of
        # the creator's primary group, which is what stops a file written by
        # one user from being unreachable to the other.
        "d /srv/code 2775 ${config.identity.username} devs -"
      ];
    }

    # Guarded the same way module/sops.nix guards its claude secrets: this
    # module is imported by hosts that may not define the claude user, and
    # naming users.users.claude unconditionally would create a half-formed
    # account on those hosts.
    (lib.mkIf (config.users.users ? claude) {
      users.users.claude.extraGroups = [ "devs" ];
    })
  ];
}
