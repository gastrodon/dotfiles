# speaches (https://speaches.ai) — local OpenAI-compatible STT/TTS server: faster-whisper
# (GPU) for speech-to-text, Kokoro (GPU) for text-to-speech, one port, no auth. This is what
# pi-voice's `openai` provider talks to when pointed locally (module/home-manager/pi-voice.nix)
# instead of real OpenAI/ElevenLabs — see that file and the OPENAI_STT_MODEL/OPENAI_TTS_MODEL/
# OPENAI_TTS_VOICE env vars it sets.
#
# No upstream Nix packaging (it's a Python+CUDA stack) and none attempted here: the project
# ships a CUDA container image, and stone already has nvidia-container-toolkit wired for CDI
# GPU passthrough (hosts/stone/configuration.nix), so this rides the same path `services.ollama`
# would if it were containerized instead of native.
{ config, lib, pkgs, ... }:
let
  cfg = config.speaches;
in
{
  options.speaches = {
    enable = lib.mkEnableOption "the local speaches STT/TTS server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Loopback-only port speaches listens on.";
    };

    sttModel = lib.mkOption {
      type = lib.types.str;
      default = "Systran/faster-distil-whisper-small.en";
      description = "HF repo id of the faster-whisper model to pre-download.";
    };

    ttsModel = lib.mkOption {
      type = lib.types.str;
      default = "speaches-ai/Kokoro-82M-v1.0-ONNX";
      description = "HF repo id of the Kokoro TTS model to pre-download.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers.speaches = {
      image = "ghcr.io/speaches-ai/speaches:latest-cuda";
      ports = [ "127.0.0.1:${toString cfg.port}:8000" ];
      # Named podman volume, not a bind mount: avoids rootless-podman host/container UID
      # mismatches, and matches speaches' own docker-run docs verbatim.
      volumes = [ "speaches-hf-cache:/home/ubuntu/.cache/huggingface/hub" ];
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
    };

    # Same spirit as services.ollama.loadModels: make sure the models pi-voice actually asks
    # for are already downloaded, rather than eating a multi-second stall (or a hard failure,
    # depending on whether speaches auto-fetches on first inference) on the first real use.
    systemd.services.speaches-model-warmup = {
      description = "Pre-download speaches STT/TTS models";
      after = [ "podman-speaches.service" ];
      requires = [ "podman-speaches.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      path = [ pkgs.curl ];
      script = ''
        base="http://127.0.0.1:${toString cfg.port}"

        until curl -sf "$base/health" >/dev/null; do
          sleep 1
        done

        curl -sf -X POST "$base/v1/models/${cfg.sttModel}"
        curl -sf -X POST "$base/v1/models/${cfg.ttsModel}"
      '';
    };
  };
}
