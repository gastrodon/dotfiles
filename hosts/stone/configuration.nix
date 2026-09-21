# Stone (Desktop) - Machine-specific configuration
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../module/avahi.nix
    ../../module/nomad-client.nix
    ../../module/claude-user.nix
    ../../module/claude-code.nix
    ../../module/linear.nix
    ../../module/pxe-boot-server.nix
    ../../module/pi-voice.nix
    ../../module/hw-bench.nix
    ../../module/tailscale.nix
  ];

  # Reach stone directly over the tailnet instead of hopping through a
  # LAN-only box — see module/tailscale.nix.
  services.tailscaleClient.enable = true;

  # Hardware bench: Uno + camera are physically attached to stone.
  hwBench.enable = true;

  # Netboot server for the server boxes; off between installs (else it loops them back into PXE).
  # This is NOT what boots the diskless cluster nodes — see wiki: PXE install
  # path vs cluster netboot, don't confuse the two.
  services.pxeBootServer = {
    enable = false;
    interface = "enp7s0";
    hostAddress = "192.168.0.77";
  };

  # PXE/RAM boot server for the diskless cluster nodes (EVA-298 / EVA-300).
  # THE DAEMON IS NOT HERE — pixiecore runs as a Nomad job; see
  # ~/code/home-infra/infra/pixiecore.nomad.hcl. These ports are just the
  # firewall hole it can't open for itself. See wiki: PXE install path vs
  # cluster netboot, don't confuse the two.
  networking.firewall.allowedUDPPorts = [
    67 # proxy-DHCP (pixiecore runs with --dhcp-no-bind, coexists with dg4244)
    69 # TFTP
    4011 # proxy-DHCP boot server port
  ];

  # Eva-readable copy of claude's SSH privkey so Claude Code (as eva) can auth as claude@server via ssh-mcp.
  sops.secrets."claude-ssh-privkey-local" = {
    sopsFile = ../../secrets.claude.yaml;
    key = "claude/ssh_privkey";
    format = "yaml";
    owner = config.identity.username;
    mode = "0600";
  };

  # pi + pi-black — stone-only, and needs no system-level wiring (auth is interactive,
  # no sops secrets), so it goes straight into home-manager rather than via a module/ wrapper.
  # 3d-print (FreeCAD) — stone-only, same reasoning: only stone has the printer/CAD workflow.
  home-manager.users.${config.identity.username}.imports = [
    ../../module/home-manager/pi.nix
    ../../module/home-manager/3d-print.nix
  ];

  networking.hostName = "stone";
  services.nomadClient.datacenter = "stone";

  desktop.terminal = pkgs.ghostty;
  desktop.hasPrivateKeys = true;
  desktop.hasSpeaker = true;

  desktop.extra.i3config = {
    workspaceOutputAssign = [
      {
        workspace = "10";
        output = "DP-3";
      }
    ];
    startup = [
      {
        command = toString (
          let
            monitors = {
              "DP-4" = "--mode 2560x1440 --rotate right --pos 0x1080";
              "DP-3" = "--primary --mode 2560x1440 --rotate normal --pos 1440x1562";
            };
            # Unspecified connected outputs default to 1080p and stack directly
            # above DP-4 (bottom edge at y = 1080), left-to-right from x = 0.
            stack = {
              bottomY = 1080;
              startX = 0;
              width = 1920;
              height = 1080;
            };
            xrandr = "${pkgs.xrandr}/bin/xrandr";
          in
          pkgs.writeShellScript "stone-monitor-layout" ''
            connected=$(${xrandr} --query | ${pkgs.gawk}/bin/awk '/ connected/ {print $1}')

            args=()
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: opts: ''
                if printf '%s\n' "$connected" | grep -qx ${lib.escapeShellArg name}; then
                  args+=(--output ${name} ${opts})
                fi
              '') monitors
            )}

            x=${toString stack.startX}
            y=$((${toString stack.bottomY} - ${toString stack.height}))
            for out in $connected; do
              case "$out" in
                ${lib.concatStringsSep "|" (lib.attrNames monitors)}) continue ;;
              esac
              args+=(--output "$out" --mode ${toString stack.width}x${toString stack.height} --rotate normal --pos "''${x}x$y")
              x=$((x + ${toString stack.width}))
            done

            if [ ''${#args[@]} -gt 0 ]; then
              ${xrandr} "''${args[@]}"
            fi
          ''
        );
        notification = false;
      }
    ];
  };

  # Direct GRUB boot (no EFI, no separate /boot)
  boot.loader.timeout = 0;
  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    timeoutStyle = "hidden";
  };

  services.upower.enable = false;
  services.udev.extraRules = "";

  # NVIDIA RTX 2080 Super
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # Use proprietary drivers, not open kernel module
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.nvidia-container-toolkit.enable = true;

  # Native CUDA-backed Ollama, available to LAN clients as stone:11434.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "0.0.0.0";
    openFirewall = true;
    loadModels = [ "qwen3:8b" ];
    # contextWindow in pi.nix must exactly match OLLAMA_CONTEXT_LENGTH here, or
    # Ollama silently truncates history. See wiki: pi model & tool-calling
    # behavior notes (EVA-152).
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "40960";
      OLLAMA_FLASH_ATTENTION = "1"; # required for quantised KV
      OLLAMA_KV_CACHE_TYPE = "q4_0";
    };
  };

  powerManagement.cpuFreqGovernor = "performance";

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];

  networking.firewall.allowedTCPPorts = [
    # Minecraft "Open to LAN" on a pinned port — direct-connect via stone.local:25565.
    25565

    # pixiecore's HTTP, serving bzImage and the ~1.5 GB initrd to booting nodes
    # (EVA-300; see the netboot block above). Not 80 or 8080 — see wiki: PXE
    # install path vs cluster netboot, don't confuse the two.
    8064
  ];

  environment.systemPackages = [
    pkgs.prismlauncher
    # extra JDKs in-closure for Prism's Java auto-detect (modpacks needing != bundled 21)
    pkgs.jdk8
    pkgs.jdk25
  ];
}
