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
    ../../module/claude-code.nix
    ../../module/bench.nix
    ../../module/tailscale.nix
  ];

  # Reach stone directly over the tailnet instead of hopping through a
  # LAN-only box — see module/tailscale.nix.
  services.tailscaleClient.enable = true;

  # Hardware bench: Uno + camera are physically attached to stone.
  hwBench.enable = true;

  # 3d-print (FreeCAD) — stone-only, same reasoning: only stone has the printer/CAD workflow.
  home-manager.users.${config.identity.username}.imports = [
    ../../module/home-manager/3d-print.nix
  ];

  networking.hostName = "stone";

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  desktop.terminal = pkgs.ghostty;
  desktop.hasPrivateKeys = true;
  desktop.hasSpeaker = true;
  desktop.session = "wayland";

  desktop.extra.swayconfig =
    let
      # Matched by make/model/serial: the NVIDIA connector names differ between Xorg and sway.
      landscape = "Acer Technologies Acer VG270U 0x023192E2";
      portrait = "Acer Technologies Acer VG270U 0x01415551";
    in
    {
      workspaceOutputAssign = [
        {
          workspace = "10";
          output = landscape;
        }
      ];
      startup = [
        {
          # A reload (home-manager's apply does one) resets outputs to the config file's, which has none.
          always = true;
          command = toString (
            let
              monitors = {
                ${portrait} = "mode 2560x1440 transform 90 pos 0 1080";
                ${landscape} = "mode 2560x1440@74.971Hz transform normal pos 1440 1562";
              };
              # Unspecified connected outputs default to 1080p and stack directly
              # above the portrait monitor (bottom edge at y = 1080), left-to-right from x = 0.
              stack = {
                bottomY = 1080;
                startX = 0;
                width = 1920;
                height = 1080;
              };
              swaymsg = "${pkgs.sway}/bin/swaymsg";
            in
            pkgs.writeShellScript "stone-monitor-layout" ''
              outputs=$(${swaymsg} -t get_outputs -r | ${pkgs.jq}/bin/jq -r '.[] | "\(.name)\t\(.make) \(.model) \(.serial)"')
              name_of() { printf '%s\n' "$outputs" | ${pkgs.gawk}/bin/awk -F'\t' -v id="$1" '$2 == id { print $1 }'; }

              args=()
              known=" "
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (id: opts: ''
                  name=$(name_of ${lib.escapeShellArg id})
                  if [ -n "$name" ]; then
                    args+=("output $name ${opts}")
                    known="$known$name "
                  fi
                '') monitors
              )}

              x=${toString stack.startX}
              y=$((${toString stack.bottomY} - ${toString stack.height}))
              for out in $(printf '%s\n' "$outputs" | cut -f1); do
                case "$known" in *" $out "*) continue ;; esac
                args+=("output $out mode ${toString stack.width}x${toString stack.height} transform normal pos $x $y")
                x=$((x + ${toString stack.width}))
              done

              if [ ''${#args[@]} -gt 0 ]; then
                ${swaymsg} "$(IFS=';'; echo "''${args[*]}")"
              fi
            ''
          );
        }
      ];
    };

  # RTX 2080 Super needs the unsupported-GPU flag; no hardware cursor on proprietary NVIDIA.
  programs.sway = {
    extraOptions = [ "--unsupported-gpu" ];
    extraSessionCommands = ''
      export WLR_NO_HARDWARE_CURSORS=1
      export GBM_BACKEND=nvidia-drm
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export WLR_RENDERER=vulkan
    '';
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
    powerManagement.enable = true;
    open = false; # Use proprietary drivers, not open kernel module
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.nvidia-container-toolkit.enable = true;

  powerManagement.cpuFreqGovernor = "performance";

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];
}
