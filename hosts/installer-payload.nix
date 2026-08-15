# Shared installer environment for the server boxes (USB live-media + PXE netboot
# deliver the identical install flow; only transport differs). `substituter`
# selects closure delivery: null = baked/USB, set = thin/netboot.
{
  pkgs,
  lib,
  targetSystem,
  diskConfig,
  diskoPkg,
  substituter ? null,
  ...
}:
let
  targetTopLevel = targetSystem.config.system.build.toplevel;

  # Thin discards string context so the path is no dependency edge — closure stays out of the netboot initrd. Baked keeps it.
  systemPath =
    if substituter == null then
      "${targetTopLevel}"
    else
      builtins.unsafeDiscardStringContext (toString targetTopLevel);

  # nixos-install forwards --option to its internal nix-env --set --store /mnt, which substitutes the closure from our unsigned http cache.
  substituterFlags = lib.optionalString (substituter != null) (
    "--option extra-substituters ${substituter} --option require-sigs false"
  );

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
    ${pkgs.nixos-install-tools}/bin/nixos-install --system ${systemPath} --no-root-passwd ${substituterFlags}

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
