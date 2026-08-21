# Secrets + wiring for the hermes-agent service (NousResearch/hermes-agent
# flake input): a Discord-facing supervisor agent that lives alongside
# pibot's Nomad-dispatched workers on server. hermes-agent's own Nix module
# owns no secrets — this file owns the sops-encrypted material (stays in
# this repo) and hands decrypted paths to the upstream module's options
# (environmentFiles, authFile).
#
# Two things must be populated in secrets.claude.yaml before this actually
# comes up:
#   hermes/env       - dotenv-style blob: DISCORD_BOT_TOKEN=..., plus
#                       DISCORD_ALLOWED_USERS=<your Discord user ID> (an
#                       empty allowlist lets any Discord user talk to it) and
#                       optionally DISCORD_HOME_CHANNEL=<channel ID> for
#                       proactive/cron messages.
#   hermes/auth_json - the ~/.hermes/auth.json produced by
#                       `hermes auth openai-codex` (device-code OAuth; run
#                       once on a workstation and copy the file over).
#
# Host trust is deliberately conservative for now: terminal.backend stays on
# hermes' sandboxed docker backend rather than local, and it gets no
# nomad/docker CLI or Nomad ACL token. Whether to grant it real
# administrative reach over this box/Nomad is a separate decision, tracked
# as a follow-up.
{ config, ... }:
{
  sops.secrets."hermes/env" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    owner = "hermes";
    mode = "0400";
  };

  sops.secrets."hermes/auth_json" = {
    sopsFile = ../secrets.claude.yaml;
    format = "yaml";
    owner = "hermes";
    mode = "0400";
  };

  services.hermes-agent = {
    enable = true;
    environmentFiles = [ config.sops.secrets."hermes/env".path ];
    authFile = config.sops.secrets."hermes/auth_json".path;

    settings = {
      discord.require_mention = true;
      # Not "local" — this box also runs Nomad/pibot; a sandboxed terminal
      # backend is the safe default until command approvals/allowlisting for
      # direct host access gets designed.
      terminal.backend = "docker";
    };
  };
}
