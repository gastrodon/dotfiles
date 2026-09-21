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
  # GitHub PAT bind-mounted into the pi-agent worker container for git clone/push + PR creation.
  sops.secrets."github/pat" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    mode = "0400";
  };
  # pi's auth.json — seeds a fresh worker box; pi rewrites its own copy as tokens rotate. See wiki.
  sops.secrets."pi/auth_json" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    mode = "0400";
  };

  # Per-workspace Linear token isn't stored here; the receiver mints it itself over OAuth. See wiki.
  services.linearAgent = {
    enable = true;
    # eva's workspace only — checked against Linear's own answer of who consented. See wiki.
    allowedOrganizations = [ "f9a4dcde-1f1d-43e1-a9c6-dbded1d624b4" ];
    webhookSecretFile = config.sops.secrets."linear/webhook_secret".path;
    clientIdFile = config.sops.secrets."linear/client_id".path;
    clientSecretFile = config.sops.secrets."linear/client_secret".path;
  };

  services.piAgent = {
    enable = true;
    githubPatFile = config.sops.secrets."github/pat".path;
    authFile = config.sops.secrets."pi/auth_json".path;
  };
}
