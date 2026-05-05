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
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "autoinstall" ''
        set -euo pipefail

        echo "=== autoinstall: 10s to power off and cancel ==="
        sleep 10

        echo ">>> partitioning and formatting..."
        ${diskoPkg}/bin/disko --mode disko ${diskConfig}

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
