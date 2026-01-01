# NixOS Bootstrap Instructions

This guide walks you through installing NixOS from a live environment using the configuration files in this repository.

## Prerequisites

1. Download the NixOS ISO from https://nixos.org/download.html (minimal ISO is fine)
2. Create a bootable USB drive with the ISO
3. Boot from the USB drive

## Installation Steps

### 1. Partition the Disk

We'll use the entire `/dev/sda` disk with a simple single-partition layout. A swap file will be created on the root partition.

```bash
# Partition the disk
sudo parted /dev/sda -- mklabel msdos
sudo parted /dev/sda -- mkpart primary ext4 1MiB 100%
sudo parted /dev/sda -- set 1 boot on

# Format the partition
sudo mkfs.ext4 -L nixos /dev/sda1
```

### 2. Mount the Filesystem

```bash
# Mount the root partition
sudo mount /dev/disk/by-label/nixos /mnt
```

### 3. Create Swap File

Create a swap file sized to match your system's RAM:

```bash
# Determine your RAM size (in MB)
RAM_SIZE=$(free -m | awk '/^Mem:/{print $2}')
echo "RAM size: ${RAM_SIZE}MB"

# Create swap file
sudo dd if=/dev/zero of=/mnt/swapfile bs=1M count=$RAM_SIZE status=progress
sudo chmod 600 /mnt/swapfile
sudo mkswap /mnt/swapfile
sudo swapon /mnt/swapfile
```

Note: The swap file will be automatically managed by NixOS after installation based on the configuration in `hardware-configuration.nix`.

### 4. Generate Initial Configuration

```bash
# Generate hardware configuration
sudo nixos-generate-config --root /mnt
```

This creates `/mnt/etc/nixos/configuration.nix` and `/mnt/etc/nixos/hardware-configuration.nix`.

### 5. Replace with Repository Configuration

Option A - If you have network access and git:
```bash
# Clone this repository
cd /mnt/etc/nixos
sudo rm configuration.nix hardware-configuration.nix
git clone https://github.com/gastrodon/dotfiles.git temp
sudo cp temp/configuration.nix .
sudo cp temp/hardware-configuration.nix .
sudo cp -r temp/module .
```

Option B - Manual copy:
```bash
# Copy the configuration files from this repository to /mnt/etc/nixos/
# You may need to use a USB drive or download them
cd /mnt/etc/nixos
sudo mkdir -p module

# Copy files:
# - configuration.nix
# - hardware-configuration.nix
# - module/users.nix
# - module/x11.nix
# - module/i3.nix
```

### 6. Review and Adjust Configuration

Before installing, review the hardware configuration:

```bash
sudo nano /mnt/etc/nixos/hardware-configuration.nix
```

**Important adjustments:**
- **Swap size**: Update the swap file size in `swapDevices` to match your RAM (in MB)
- Verify the filesystem UUIDs match your actual partitions (you can use `blkid` to check)
- If you have AMD CPU instead of Intel, change the microcode line in hardware-configuration.nix
- Adjust timezone in configuration.nix if needed (default is America/New_York)

### 7. Install NixOS

```bash
# Run the installation
sudo nixos-install

# This will:
# - Build the system configuration
# - Install all packages
# - Set up the bootloader
```

The installation may take several minutes depending on your internet connection and hardware.

### 8. Reboot

```bash
# Reboot into the new system
sudo reboot
```

Remove the USB drive when prompted.

## Post-Installation

### First Login

1. At the login prompt, log in as user `eva` with no password (just press Enter)
2. Start the graphical environment:
   ```bash
   startx
   ```

This will:
- Load X resources from `.Xresources` (if present)
- Execute `.xinitrc` which starts i3
- Launch the i3 window manager

### Set a Password (IMPORTANT)

For security, set a password immediately:
```bash
passwd
```

### Configure i3

On first launch, i3 will ask you to:
1. Generate a config file - press Enter to accept
2. Choose the modifier key - press Enter to use Win/Super key (recommended)

### Additional Configuration

To use the full dotfiles configuration:

1. Clone this repository to your home directory:
   ```bash
   cd ~
   git clone https://github.com/gastrodon/dotfiles.git
   cd dotfiles
   ```

2. Link the dotfiles (use the existing link script):
   ```bash
   ./link
   ```

This will symlink all the configuration files to their proper locations.

### Updating the System

To update packages and rebuild the system:
```bash
sudo nixos-rebuild switch
```

To update the package channel:
```bash
sudo nix-channel --update
sudo nixos-rebuild switch
```

## Troubleshooting

### X Server Won't Start

If `startx` fails:
1. Check X server logs: `cat ~/.local/share/xorg/Xorg.0.log`
2. Verify i3 is installed: `which i3`
3. Check your `.xinitrc` file exists and is executable

### Boot Issues

If the system won't boot:
1. Boot back into the live USB
2. Mount the partition: `sudo mount /dev/sda1 /mnt`
3. Check bootloader: `sudo nixos-enter --root /mnt`
4. Verify GRUB installation: `sudo grub-install /dev/sda`

### No Network After Install

Enable NetworkManager:
```bash
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
```

### Permission Issues

If you can't use sudo:
```bash
# As root
usermod -aG wheel eva
```

## Architecture Overview

The configuration is split into modules:

- **configuration.nix** - Main system configuration, imports all modules
- **hardware-configuration.nix** - Hardware-specific settings (generated, then modified)
- **module/users.nix** - User account configuration
- **module/x11.nix** - X Window System setup
- **module/i3.nix** - i3 window manager configuration

This modular approach makes it easy to:
- Enable/disable features by commenting out imports
- Share configurations between machines
- Maintain clean separation of concerns

## Next Steps

After basic installation:
1. Set a secure password for user eva
2. Configure networking (WiFi, etc.)
3. Add more packages as needed in configuration.nix
4. Customize i3 configuration
5. Set up additional dotfiles from this repository
6. Consider migrating to Home Manager for user-level configuration

For more advanced configuration, refer to:
- NixOS Manual: https://nixos.org/manual/nixos/stable/
- Nix Pills: https://nixos.org/guides/nix-pills/
- Home Manager: https://github.com/nix-community/home-manager
