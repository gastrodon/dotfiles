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
  ];

  home-manager.users.${config.identity.username}.imports = [
    ../../module/home-manager/claude.nix
  ];

  ifunnyRe.waydroidUser = config.identity.username;

  networking.hostName = "stone";
  services.nomadClient.datacenter = "stone";

  desktop.terminal = pkgs.ghostty;
  desktop.hasPrivateKeys = true;
  desktop.hasSpeaker = true;

  desktop.extra.i3config = {
    workspaceOutputAssign = [
      { workspace = "10"; output = "DP-3"; }
    ];
    startup = [
      {
        command = toString (
          let
            monitors = {
              "DP-4" = "--mode 2560x1440 --rotate right --pos 0x1080";
              "DP-3" = "--mode 2560x1440 --rotate normal --pos 1440x1763";
            };
            # Unspecified connected outputs default to 1080p and stack directly
            # above DP-4 (bottom edge at y = 1080), left-to-right from x = 0.
            stack = {
              bottomY = 1080;
              startX = 0;
              width = 1920;
              height = 1080;
            };
            xrandr = "${pkgs.xorg.xrandr}/bin/xrandr";
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

  # Desktop: Direct GRUB boot (no EFI, no separate /boot partition)
  boot.loader.timeout = 0;
  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    timeoutStyle = "hidden";
  };

  # Desktop: Disable laptop-specific services
  services.upower.enable = false;

  # Desktop: No backlight controls
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
  powerManagement.cpuFreqGovernor = "performance";

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];

  environment.systemPackages = [
    pkgs.prismlauncher
    # Extra JDKs kept in the closure so Prism's Java auto-detect can pick them
    # for modpacks that need something other than the launcher's bundled 21.
    pkgs.jdk8
    pkgs.jdk25
  ];
}
