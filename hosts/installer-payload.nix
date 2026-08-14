# Shared installer environment for the server boxes. Imported by both the USB
# live-media ISO (hosts/live-media.nix) and the PXE netboot image
# (hosts/netboot.nix) so both deliver the exact same install flow — the only
# difference between them is transport (USB vs network), not behaviour.
#
# The target system closure is baked into the image by the importing host
# (isoImage.storeContents / netboot storeContents); here we only define the
# `install-server` script, the login users, and the boot banner.
{
  pkgs,
  targetSystem,
  diskConfig,
  diskoPkg,
  ...
}:
let
  targetTopLevel = targetSystem.config.system.build.toplevel;

  installServerScript = pkgs.writeShellScriptBin "install-server" ''
    set -euo pipefail

    echo ">>> resolving target disk (internal, fixed, non-USB)..."
    mapfile -t disks < <(${pkgs.util-linux}/bin/lsblk -dpno NAME,RM,TYPE,TRAN \
      | ${pkgs.gawk}/bin/awk '$3 == "disk" && $2 == 0 && $4 != "usb" { print $1 }')

    if [ "''${#disks[@]}" -ne 1 ]; then
      echo "!!! expected exactly one internal disk, found ''${#disks[@]}:" >&2
      printf '      %s\n' "''${disks[@]}" >&2
      echo "    aborting — narrow the candidates or partition by hand." >&2
      exit 1
    fi
    disk="''${disks[0]}"
    echo ">>> target disk: $disk"

    echo ">>> partitioning and formatting $disk..."
    ${diskoPkg}/bin/disko --mode disko --argstr device "$disk" ${diskConfig}

    echo ">>> installing NixOS..."
    ${pkgs.nixos-install-tools}/bin/nixos-install --system ${targetTopLevel} --no-root-passwd

    echo ">>> installing keys into /mnt/var/lib/sops-nix/..."
    sudo mkdir -p /mnt/var/lib/sops-nix
    sudo install -m 400 -o root -g root /tmp/bootstrap-key.txt.staged /mnt/var/lib/sops-nix/bootstrap-key.txt
    sudo install -m 400 -o root -g root /tmp/github-deploy-key.staged /mnt/var/lib/sops-nix/github-deploy-key

    echo ">>> cloning dotfiles into /mnt/home/claude/dotfiles..."
    sudo mkdir -p /mnt/home/claude
    sudo ${pkgs.git}/bin/git clone https://github.com/gastrodon/dotfiles /mnt/home/claude/dotfiles

    echo ">>> done — reboot when ready"
  '';
in
{
  environment.systemPackages = [
    diskoPkg
    pkgs.git
    pkgs.sops
    installServerScript
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
    };
  };

  users.users.eva = {
    isNormalUser = true;
    group = "eva";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [
      (builtins.fetchurl "https://github.com/gastrodon.keys")
    ];
  };

  users.groups.eva = { };

  users.users.claude = {
    isNormalUser = true;
    group = "claude";
    openssh.authorizedKeys.keyFiles = [ ../keys/claude.pub ];
  };

  users.groups.claude = { };

  security.sudo.wheelNeedsPassword = false;

  systemd.services.motd = {
    description = "Print installer boot banner";
    wantedBy = [ "getty@tty1.service" ];
    before = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "motd" ''
        cat << 'EOF'

        ========================================
        NixOS Server Installer
        ========================================

        SSH as eva or claude to begin installation.
        Available on this LAN at:
          $(${pkgs.iproute2}/bin/ip -4 addr show up primary scope global | ${pkgs.gawk}/bin/awk '{print $4; exit}' | ${pkgs.gnused}/bin/sed 's|/[0-9]*||')

        Once logged in as eva, run:
          sudo install-server

        After completion, reboot to boot the installed system.

        ========================================

        EOF
      '';
    };
  };
}
