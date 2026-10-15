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
    ../../module/lab/tea.nix
    ../../module/lab/bench.nix
    ../../module/tailscale.nix
  ];

  # Reach stone directly over the tailnet instead of hopping through a
  # LAN-only box — see module/tailscale.nix.
  services.tailscaleClient.enable = true;

  # Hardware bench: Uno + camera are physically attached to stone.
  hwBench.enable = true;

  # PXE/RAM boot server for the diskless cluster nodes (EVA-298 / EVA-300).
  # THE DAEMON IS NOT HERE — pixiecore runs as a Nomad job; see
  # lab/nomad-jobs infra/pixiecore.nomad.hcl. These ports are just the
  # firewall hole it can't open for itself.
  networking.firewall.allowedUDPPorts = [
    67 # proxy-DHCP (pixiecore runs with --dhcp-no-bind, coexists with dg4244)
    69 # TFTP
    4011 # proxy-DHCP boot server port
  ];

  # pi + pi-black — stone-only, and needs no system-level wiring (auth is interactive,
  # no sops secrets), so it goes straight into home-manager rather than via a module/ wrapper.
  # 3d-print (FreeCAD) — stone-only, same reasoning: only stone has the printer/CAD workflow.
  home-manager.users.${config.identity.username}.imports = [
    ../../module/home-manager/pi.nix
    ../../module/home-manager/3d-print.nix
  ];

  networking.hostName = "stone";

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  services.nomadClient.datacenter = "stone";

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

  networking.firewall.allowedTCPPorts = [
    # pixiecore's HTTP, serving bzImage and the ~1.5 GB initrd to booting nodes
    # (EVA-300; see the netboot block above). Not 80 or 8080 — see wiki: PXE
    # install path vs cluster netboot, don't confuse the two.
    8064
  ];

  environment.systemPackages = [
    pkgs.openbao
  ];
}
