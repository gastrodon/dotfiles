# Secrets from eva's passage store, injected as root-owned-by-config files.
# Declare `passage.secrets.<PASSAGE_KEY>` and read `.path`; the file always exists (empty until synced).
# Root can't read the store, so `passage-sync` (run as the user) copies each key to its path.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.passage;

  syncLine = s: ''
    sync ${lib.escapeShellArg s.name} ${lib.escapeShellArg s.path} ${s.mode} ${s.owner} ${s.group}
    ${lib.concatMapStringsSep "\n" (u: "restart ${lib.escapeShellArg u}") s.restartUnits}
  '';

  passage-sync = pkgs.writeShellApplication {
    name = "passage-sync";
    runtimeInputs = [
      pkgs.passage
      pkgs.coreutils
    ];
    text = ''
      declare -A restarts=()
      sync() {
        local value
        if ! value="$(passage show "$1" 2>/dev/null)"; then
          echo "passage-sync: no passage key $1, leaving $2 as is" >&2
          return 0
        fi
        printf '%s' "$value" | sudo install -m "$3" -o "$4" -g "$5" -D /dev/stdin "$2"
      }
      restart() { restarts["$1"]=1; }
      ${lib.concatMapStringsSep "\n" syncLine (lib.attrValues cfg.secrets)}
      for unit in "''${!restarts[@]}"; do
        sudo systemctl restart "$unit"
      done
    '';
  };
in
{
  options.passage.secrets = lib.mkOption {
    default = { };
    description = "Passage keys to materialize as files, keyed by passage key name.";
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "Passage key name.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              default = "/var/lib/passage/${name}";
              description = "Where the value is written.";
            };
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0400";
            };
            restartUnits = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Units restarted by passage-sync after the value is written.";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (cfg.secrets != { }) {
    systemd.tmpfiles.rules =
      map (d: "d ${d} 0755 root root -") (lib.unique (map (s: dirOf s.path) (lib.attrValues cfg.secrets)))
      ++ lib.mapAttrsToList (_: s: "f ${s.path} ${s.mode} ${s.owner} ${s.group} -") cfg.secrets;

    environment.systemPackages = [ passage-sync ];
  };
}
