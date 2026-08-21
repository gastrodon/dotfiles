# pi-voice — push-to-talk voice daemon for `pi` (./pi.nix). Upstream ships no Nix packaging;
# packaged via bun2nix in a scoped fork (github:auto-patcher/pi-voice, wired in flake.nix). See
# that repo's default.nix for the Electron/native-addon packaging details, and its stt.ts/tts.ts
# patches for why the local Whisper provider still isn't safe to select (crashes the daemon) and
# how the `openai` provider gets pointed at a local server instead of real OpenAI.
#
# Two providers are wired up here:
# - `elevenlabs` — eva's own key (secrets.yaml, out of ring), read into the daemon's own env by
#   this wrapper only, never the model, same pattern as the AWS secret in claude.nix.
# - `openai` — repointed at the local speaches server (../speaches.nix) instead of real OpenAI,
#   via the same OPENAI_BASE_URL/OPENAI_API_KEY env vars the SDK already reads on its own, plus
#   OPENAI_STT_MODEL/OPENAI_TTS_MODEL/OPENAI_TTS_VOICE to select speaches' own model/voice ids
#   instead of OpenAI's. No secret involved (speaches has no auth); the API key is a dummy value
#   the SDK requires be non-empty. Port/model ids must match ../speaches.nix's own defaults.
#
# `openai` (local speaches) is also the default provider, via PI_VOICE_PROVIDER — pi-voice's own
# fallback (used only when a project has no .pi/pi-voice.json) — so no per-project config file is
# needed for the common case. A project can still drop its own .pi/pi-voice.json to override this
# (e.g. to pick elevenlabs, or a different key binding), which always takes priority.
{
  pkgs,
  lib,
  pi-voice,
  ...
}:
let
  piVoicePkg = pi-voice.packages.${pkgs.stdenv.hostPlatform.system}.default;

  wrapped = pkgs.writeShellApplication {
    name = "pi-voice";
    text = ''
      ELEVENLABS_API_KEY="$(< /run/secrets/elevenlabs/api_key)"
      export ELEVENLABS_API_KEY

      export PI_VOICE_PROVIDER="openai"
      # Super+C — confirmed free in module/home-manager/i3.nix (only Mod4+Shift+c is bound,
      # to "reload"). Push-to-talk is a global X11 hook (uiohook), independent of i3's own
      # bindsym grabs either way, but a free combo avoids i3 also firing on the same keypress.
      export PI_VOICE_KEY="super+c"

      export OPENAI_BASE_URL="http://127.0.0.1:8000/v1"
      export OPENAI_API_KEY="speaches-no-auth-required"
      export OPENAI_STT_MODEL="Systran/faster-distil-whisper-small.en"
      export OPENAI_TTS_MODEL="speaches-ai/Kokoro-82M-v1.0-ONNX"
      export OPENAI_TTS_VOICE="af_heart"

      exec ${lib.getExe piVoicePkg} "$@"
    '';
  };
in
{
  home.packages = [ wrapped ];
}
