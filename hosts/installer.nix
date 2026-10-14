{
  pkgs,
  targetSystem,
  diskConfig,
  diskoPkg,
  ...
}:
let
  targetTopLevel = targetSystem.config.system.build.toplevel;
  hostName = targetSystem.config.networking.hostName;
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
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "autoinstall" ''
        set -euo pipefail

        echo "=== autoinstall: 10s to power off and cancel ==="
        sleep 10

        echo ">>> reading the pre-generated ssh host key from the HOSTKEYS stick..."
        mkdir -p /run/hostkeys
        mount -o ro /dev/disk/by-label/HOSTKEYS /run/hostkeys
        test -s /run/hostkeys/${hostName}/ssh_host_ed25519_key
        test -s /run/hostkeys/${hostName}/ssh_host_ed25519_key.pub

        echo ">>> partitioning and formatting..."
        disko --mode disko ${diskConfig}

        echo ">>> installing NixOS..."
        nixos-install --system ${targetTopLevel} --no-root-passwd

        echo ">>> installing the ssh host key..."
        install -D -m 600 /run/hostkeys/${hostName}/ssh_host_ed25519_key /mnt/etc/ssh/ssh_host_ed25519_key
        install -D -m 644 /run/hostkeys/${hostName}/ssh_host_ed25519_key.pub /mnt/etc/ssh/ssh_host_ed25519_key.pub
        umount /run/hostkeys

        echo ">>> done — rebooting in 5s"
        sleep 5
        reboot
      '';
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };
}
