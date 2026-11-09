{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.android-tools ];

  # Meta Quest (USB VID 2833): uaccess must be tagged before 73-seat-late, so this can't go in extraRules (99-local).
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-quest.rules" ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="2833", MODE="0660", TAG+="uaccess"
    '')
  ];
}
