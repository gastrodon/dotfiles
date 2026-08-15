# PXE netboot image for the server boxes. Thin: the RAM initrd carries only the
# installer environment, NOT the target system closure — the box substitutes
# that from stone's http binary cache into the SSD at install time (see the
# `substituter` arg threaded through installer-payload.nix). All install
# behaviour is shared with the USB path via that payload.
#
# The whole point is to leave `netboot.storeContents` at its default (just the
# installer's own toplevel); adding the target closure here would defeat thin.
{
  ...
}:
{
  imports = [ ./installer-payload.nix ];
}
