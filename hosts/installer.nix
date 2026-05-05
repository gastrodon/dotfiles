{
  pkgs,
  targetSystem,
  diskConfig,
  diskoPkg,
  ...
}:
let
  targetTopLevel = targetSystem.config.system.build.toplevel;
in
{
  isoImage.storeContents = [ targetTopLevel ];

  environment.systemPackages = [ diskoPkg ];

  systemd.services.autoinstall = {
    description = "NixOS Autoinstall";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    path = [
      diskoPkg
      pkgs.nixos-install-tools
      pkgs.nix
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "autoinstall" ''
        set -euo pipefail

        DEVICE=$(grep -oP 'disko\.device=\K\S+' /proc/cmdline || true)
        if [[ -z "''${DEVICE}" ]]; then
          echo "ERROR: no disko.device= found in kernel cmdline" >&2
          exit 1
        fi

        echo "=== autoinstall: 10s to power off and cancel ==="
        sleep 10

        echo ">>> partitioning and formatting on ''${DEVICE}..."
        disko --mode disko ${diskConfig} --arg device "\"''${DEVICE}\""

        echo ">>> installing NixOS..."
        nixos-install --system ${targetTopLevel} --no-root-passwd

        echo ">>> done — rebooting in 5s"
        sleep 5
        reboot
      '';
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };
}
