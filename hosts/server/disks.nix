# Single-disk layout for the generic server boxes (one 120GB SSD).
#
# Works two ways:
#   - as a NixOS module (imported by configuration.nix) — `device` defaults,
#     and only the by-partlabel mounts end up in the toplevel, so the default
#     is inert on the installed system.
#   - as a disko CLI target — the installer passes the real disk at format
#     time with `disko --argstr device /dev/… --mode disko ./disks.nix`.
{ device ? "/dev/sda", ... }:
{
  disko.devices.disk.main = {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
