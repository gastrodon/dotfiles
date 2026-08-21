# pi-voice push-to-talk daemon (module/home-manager/pi-voice.nix) — stone-only, needs the
# ElevenLabs key. eva-only (secrets.yaml, out of ring): wires the sops secret its home-manager
# wrapper consumes. Hosts that skip this module never decrypt it.
#
# Also brings up speaches (./speaches.nix) — local GPU STT/TTS — as the `openai` provider's
# actual local target; see module/home-manager/pi-voice.nix for how the two connect.
{ config, ... }:
{
  imports = [ ./speaches.nix ];

  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/pi-voice.nix
  ];

  sops.secrets."elevenlabs/api_key".owner = config.identity.username;

  speaches.enable = true;
}
