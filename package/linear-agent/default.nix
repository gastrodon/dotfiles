{ pkgs, lib, ... }:

pkgs.buildGoModule {
  pname = "linear-agent";
  version = "0.1.0";

  src = ./.;

  # stdlib-only, no external modules
  vendorHash = null;

  meta = with lib; {
    description = "Linear agent-session webhook receiver → Nomad dispatch";
    license = licenses.mit;
    maintainers = [ ];
  };
}
