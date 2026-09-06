# Secrets + wiring for the pibot services (gastrodon/pibot flake input): the
# Linear agent-session webhook receiver (services.linearAgent) and the
# isolated pi worker Nomad job it dispatches (services.piAgent). pibot's own
# Nix modules own no secrets — this file owns the sops-encrypted material
# (stays in this repo) and hands decrypted secret *paths* to pibot's module
# options.
{ config, ... }:
{
  sops.secrets."linear/webhook_secret" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    owner = "linear-agent";
  };
  sops.secrets."linear/client_id" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    owner = "linear-agent";
  };
  sops.secrets."linear/client_secret" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    owner = "linear-agent";
  };
  # Same underlying value as sops.secrets."nomad/bootstrap_token" (module/sops.nix,
  # owner=claude) but re-keyed to a copy owned by linear-agent — the receiver
  # needs its own readable copy to authenticate its Nomad dispatch calls.
  sops.secrets."linear-agent/nomad_token" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    key = "nomad/bootstrap_token";
    owner = "linear-agent";
  };
  # GitHub PAT bind-mounted into the pi-agent worker container for git
  # clone/push + PR creation. Root-only — the register service and the podman
  # bind-mount both run as root.
  sops.secrets."github/pat" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    mode = "0400";
  };
  # pi's auth.json — the provider credentials the worker runs on. A fresh
  # worker box has an empty /var/lib/pi-agent/home, and pi answers every prompt
  # on such a node with "No API key found for the selected model" and then sits
  # idle until the run is killed, which reaches Linear as a contentless reply.
  # Seeding it from here means a new box becomes a working worker the moment
  # bootstrap plants claude's age key and the config is deployed — no manual
  # login per box. pi rewrites its own copy as tokens rotate; this is only the
  # starting point, never a clobber.
  sops.secrets."pi/auth_json" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    mode = "0400";
  };

  # Only app-level material is wired here. The per-workspace Linear token is
  # not a secret this repo carries any more: the receiver mints it itself over
  # OAuth (${publicUrl}/oauth/start) into /var/lib/linear-agent, so
  # re-authorizing is a browser visit rather than a `sops set` plus a redeploy.
  # publicUrl is set per host, next to the funnel that serves it.
  services.linearAgent = {
    enable = true;
    # eva's workspace. Both OAuth endpoints are public through the funnel, so
    # even a caller who gets past the admin token can only install a workspace
    # named here — and Linear is asked which workspace consented, so this is
    # checked against Linear's answer, not the caller's.
    allowedOrganizations = [ "f9a4dcde-1f1d-43e1-a9c6-dbded1d624b4" ];
    webhookSecretFile = config.sops.secrets."linear/webhook_secret".path;
    clientIdFile = config.sops.secrets."linear/client_id".path;
    clientSecretFile = config.sops.secrets."linear/client_secret".path;
    nomadTokenFile = config.sops.secrets."linear-agent/nomad_token".path;
  };

  services.piAgent = {
    enable = true;
    githubPatFile = config.sops.secrets."github/pat".path;
    nomadBootstrapTokenFile = config.sops.secrets."nomad/bootstrap_token".path;
    authFile = config.sops.secrets."pi/auth_json".path;
  };
}
