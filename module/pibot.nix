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
  sops.secrets."linear/refresh_token" = {
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

  services.linearAgent = {
    enable = true;
    webhookSecretFile = config.sops.secrets."linear/webhook_secret".path;
    refreshTokenFile = config.sops.secrets."linear/refresh_token".path;
    clientIdFile = config.sops.secrets."linear/client_id".path;
    clientSecretFile = config.sops.secrets."linear/client_secret".path;
    nomadTokenFile = config.sops.secrets."linear-agent/nomad_token".path;
  };

  services.piAgent = {
    enable = true;
    githubPatFile = config.sops.secrets."github/pat".path;
    nomadBootstrapTokenFile = config.sops.secrets."nomad/bootstrap_token".path;
  };
}
