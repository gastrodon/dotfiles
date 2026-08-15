# Shared installer environment for the server boxes. Imported by both the USB
# live-media ISO (hosts/live-media.nix) and the PXE netboot image
# (hosts/netboot.nix) so both deliver the exact same install flow — the only
# difference between them is transport (USB vs network), not behaviour.
#
# Two closure-delivery shapes, selected by `substituter`:
#   - null (USB): the target closure is baked into the image by the importing
#     host (isoImage.storeContents), and install-server references it as a
#     context-carrying store path so it's a genuine dependency of the image.
#   - set (netboot): thin. install-server references the target closure only as
#     a bare (context-discarded) path string, so it is NOT dragged into the RAM
#     initrd; nixos-install substitutes it straight into /mnt from `substituter`
#     (stone's http binary cache) at install time.
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

  # Baked: keep the context so the closure is a dependency of the image.
  # Thin: discard the context so referencing the path here creates no
  # dependency edge — the closure stays out of the netboot initrd.
  systemPath =
    if substituter == null then
      "${targetTopLevel}"
    else
      builtins.unsafeDiscardStringContext (toString targetTopLevel);

  # nixos-install forwards --option to its internal `nix-env --set --store /mnt`
  # (verified against nixos-install.sh), which then substitutes the closure into
  # /mnt from our unsigned http cache.
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
