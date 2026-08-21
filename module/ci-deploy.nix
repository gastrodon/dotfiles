# Wiring that lets GitHub Actions reach and deploy this host: a dedicated
# root SSH key, kept separate from eva's personal key (module/users.nix's
# `githubKeys`) so it can be rotated/revoked on its own, and a "tag:server"
# Tailscale tag so CI can enumerate deploy targets by tag instead of
# hardcoding LAN IPs (module/hosts.nix drifts — see its own comment:
# "current router leases, not yet DHCP-reserved").
#
# Neither half does anything until one-time setup happens outside this repo:
#   - keys/ci-deploy.pub doesn't exist until a deploy keypair is generated
#     and the public half committed. Until then this is a no-op, same
#     pathExists-guard pattern module/sops.nix uses for secrets.yaml.
#   - tag:server has to exist in the tailnet's ACL policy (tagOwners) before
#     --advertise-tags does anything; Tailscale silently ignores an
#     unrecognized tag rather than erroring.
#
# See .github/workflows/deploy.yml for what CI does with this and the
# tailnet ACL changes it needs.
{ lib, ... }:
{
  users.users.root.openssh.authorizedKeys.keyFiles = lib.optional (
    builtins.pathExists ../keys/ci-deploy.pub
  ) ../keys/ci-deploy.pub;

  services.tailscale.extraSetFlags = [ "--advertise-tags=tag:server" ];
}
