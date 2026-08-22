# Lets GitHub Actions reach and deploy this host: a dedicated root SSH key,
# kept separate from eva's personal key (module/users.nix's `githubKeys`) so
# it can be rotated on its own, and a "tag:server" Tailscale tag so CI can
# enumerate deploy targets by tag instead of hardcoding IPs.
#
# Both are no-ops until set up outside this repo: keys/ci-deploy.pub doesn't
# exist until the deploy keypair is generated and its public half committed,
# and tag:server needs to exist in the tailnet ACL's tagOwners before
# --advertise-tags does anything. See .github/workflows/deploy.yml.
{ lib, ... }:
{
  users.users.root.openssh.authorizedKeys.keyFiles = lib.optional (
    builtins.pathExists ../keys/ci-deploy.pub
  ) ../keys/ci-deploy.pub;

  services.tailscale.extraSetFlags = [ "--advertise-tags=tag:server" ];
}
