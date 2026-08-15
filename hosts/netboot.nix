# Thin PXE netboot image: installer only (no target closure); the box substitutes it from stone's cache at install time.
{
  ...
}:
{
  imports = [ ./installer-payload.nix ];
}
