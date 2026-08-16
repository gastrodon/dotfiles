# schpet/linear-cli — Linear issue tracker from the command line, from the upstream
# release tarball (a Deno single-file executable: the JS payload is appended to the ELF,
# and *any* patchelf rewrite drops it — the binary then dies with "Could not find
# standalone binary section"). So autoPatchelfHook is out, and with the interpreter left
# as /lib64/ld-linux-x86-64.so.2 it needs an FHS view of the filesystem to run at all.
# buildFHSEnv supplies exactly that, without relying on the host's nix-ld.
#
# Auth resolves as --api-key > LINEAR_API_KEY > .linear.toml > OS keyring. We take the
# env var and feed it from sops (see module/linear.nix), so `linear auth login` and its
# libsecret keyring never enter the picture — no interactive runtime state to manage.
#
# No shell completions: generating them means running the binary, which the build sandbox
# can't do (no FHS root, no nix-ld) — `linear completions zsh` prints them on demand.
{ pkgs, lib, ... }:
let
  version = "2.5.0";

  toml = pkgs.formats.toml { };

  linear-bin = pkgs.fetchzip {
    url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-x86_64-unknown-linux-gnu.tar.xz";
    hash = "sha256-oTA1Cm0kAmhD2Mgs4xo8IyD4sjszT3HVC3qyuNuj8aM=";
  };

  linear-cli = pkgs.buildFHSEnv {
    name = "linear";

    # git/jj: the CLI reads the current branch or commit trailers to pick the issue.
    # gh: `linear issue pr` shells out to it. The rest is what the ELF links against.
    targetPkgs =
      p: with p; [
        glibc
        gcc-unwrapped.lib
        git
        jujutsu
        gh
      ];

    runScript = "${linear-bin}/linear";

    meta = with lib; {
      description = "Linear without leaving the command line: list, start, and create PRs for Linear issues";
      homepage = "https://github.com/schpet/linear-cli";
      license = licenses.isc;
      platforms = [ "x86_64-linux" ];
      mainProgram = "linear";
    };
  };
in
{
  home.packages = [ linear-cli ];

  # Global fallback config. Deliberately a file and not LINEAR_TEAM_ID/LINEAR_WORKSPACE:
  # env vars outrank every .linear.toml, so exporting them would make a per-repo config
  # impossible to honour. As a file it sits last in the lookup order (cwd > repo root >
  # repo .config > here), so any repo that wants a different team just says so.
  home.file.".config/linear/linear.toml".source = toml.generate "linear.toml" {
    workspace = "gastrodon";
    team_id = "EVA";
  };

  # Read at shell start rather than baked into the store: the value lives only in the
  # sops runtime secret. Guarded so a shell on a host without that secret still starts clean.
  programs.zsh.initContent = lib.mkOrder 550 ''
    [ -r /run/secrets/linear/api_key ] && export LINEAR_API_KEY="$(< /run/secrets/linear/api_key)"
  '';
}
