# Claude Desktop (the GUI app) + Cowork's micro-VM sandbox — EVA-592. Import
# on hosts where eva runs Cowork locally (stone, for now). Separate from
# claude-code.nix, which wires the CLI.
#
# nmcbride/claude-desktop-nix over the other candidate flakes: its module
# satisfies Cowork's hard-coded FHS probes (OVMF firmware, virtiofsd) via
# systemd-tmpfiles symlinks into the Nix store, rather than regex-patching the
# app's minified JS to point at store paths directly — more durable against
# upstream Electron bundle changes.
{
  claude-desktop-nix,
  config,
  ...
}:
{
  imports = [ claude-desktop-nix.nixosModules.default ];

  programs.claude-desktop = {
    enable = true;
    cowork.kvmUsers = [ config.identity.username ];
  };
}
