# Single-disk layout for the generic server boxes (one 120GB SSD). Doubles as a
# NixOS module (default `device`, inert) and a disko CLI target (--argstr device at install).
{
  device ? "/dev/sda",
  ...
}:
{
  disko.devices.disk.main = {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        # EF02 BIOS-boot partition — GRUB embeds core.img here (GPT + legacy BIOS, no ESP).
        boot = {
          size = "1M";
          type = "EF02";
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
