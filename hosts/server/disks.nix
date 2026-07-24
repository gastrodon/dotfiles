{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/ata-KINGSTON_SQ500S37120G_50026B7783512442";
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
      data0 = {
        device = "/dev/disk/by-id/ata-WDC_WD60EZAZ-00ZGHB0_WD-WX12D10E0NH9";
        type = "disk";
        content = {
          type = "gpt";
          partitions.pv = {
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "data";
            };
          };
        };
      };
      data1 = {
        device = "/dev/disk/by-id/ata-WDC_WD60EZAZ-00ZGHB0_WD-WX12D10KPRU4";
        type = "disk";
        content = {
          type = "gpt";
          partitions.pv = {
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "data";
            };
          };
        };
      };
    };
    lvm_vg.data = {
      type = "lvm_vg";
      lvs.data = {
        size = "100%FREE";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/data";
        };
      };
    };
  };
}
