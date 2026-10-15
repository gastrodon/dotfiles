{ pkgs }:
let
  common = ''
    usage() {
      cat >&2 <<EOF
    Usage: nix run .#<switch|update|add-host|remove-host> -- [hostname] [options]

    Commands:
      update             nix flake update
      switch             Switch to new configuration + restart i3 / reload sway
      add-host           Make this host's ssh host key a sops decrypter of secrets.yaml
      remove-host HOST   Drop HOST as a decrypter and re-encrypt secrets.yaml under a new data key

    Options:
      --target HOST      Remote SSH target (repeatable; if specified, switch remotes)

    Examples:
      nix run .#switch -- twink
      nix run .#switch -- twink --target root@192.168.1.10
      nix run .#switch -- stone --target root@host1 --target root@host2

    Building is nix build: .#<host> for the system, .#iso-<host> for its installer ISO.
    EOF
      exit 1
    }

    if [[ $EUID -eq 0 ]]; then
      echo "Error: run as your user, not under sudo; switch asks for sudo itself" >&2
      exit 1
    fi

    ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT=""
    if [[ -z "$ROOT" || ! -f "$ROOT/hosts/shared.nix" || ! -f "$ROOT/.sops.yaml" ]]; then
      echo "Error: run this from inside the dotfiles repo" >&2
      exit 1
    fi

    HOST_ARG=""
    if [[ $# -gt 0 && "$1" != --* ]]; then
      HOST_ARG="$1"
      shift
    fi
    HOSTNAME="''${HOST_ARG:-''${NIXOS_HOSTNAME:-$(hostname)}}"

    declare -a TARGET_HOSTS=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --target)
          [[ -z "''${2:-}" ]] && { echo "Error: --target requires an argument" >&2; exit 1; }
          TARGET_HOSTS+=("$2")
          shift 2
          ;;
        *)
          echo "Error: unknown option '$1'" >&2
          usage
          ;;
      esac
    done

    # Nix's git+ssh fetcher offers every ssh-agent key; isolate to the primary one.
    # If we can't unlock it here (e.g. no TTY for the passphrase prompt), fall back
    # to the caller's existing agent rather than leaving an empty one active.
    isolate_ssh_agent() {
      [[ -f "$HOME/.ssh/id_ed25519" ]] || return 0
      ORIGINAL_SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-}"
      eval "$(ssh-agent -s)" >/dev/null
      trap 'ssh-agent -k >/dev/null 2>&1 || true' EXIT
      if ! ssh-add -q "$HOME/.ssh/id_ed25519" </dev/null >/dev/null 2>&1; then
        ssh-agent -k >/dev/null 2>&1 || true
        trap - EXIT
        export SSH_AUTH_SOCK="$ORIGINAL_SSH_AUTH_SOCK"
      fi
    }

    # Run a nixos-rebuild subcommand across all targets, continuing past per-target
    # failures (e.g. switch-to-configuration exits 4 when a remote box with a live
    # desktop session can't reload user units - system switch still lands) so one
    # bad host doesn't block the rest. Prints a summary and exits nonzero overall
    # if any target failed.
    run_multi_target() {
      local subcmd="$1"
      local -a failed=()
      echo "Running '$subcmd' for $HOSTNAME on ''${#TARGET_HOSTS[@]} target(s)..."
      for target in "''${TARGET_HOSTS[@]}"; do
        echo "  → $target"
        if ! nixos-rebuild "$subcmd" --flake "$ROOT#$HOSTNAME" --target-host "$target"; then
          echo "  ✗ $target failed" >&2
          failed+=("$target")
        fi
      done
      if [[ ''${#failed[@]} -gt 0 ]]; then
        echo "Failed targets: ''${failed[*]}" >&2
        return 1
      fi
    }

    # Runs a command with SOPS_AGE_KEY from a throwaway unlocked copy of eva's ssh key, shredded on exit.
    with_eva_age_key() {
      UNLOCK_DIR="$(mktemp -d -p "''${XDG_RUNTIME_DIR:-/dev/shm}")"
      trap 'shred -u "$UNLOCK_DIR"/* 2>/dev/null || true; rm -rf "$UNLOCK_DIR"' EXIT
      install -m 600 "$HOME/.ssh/id_ed25519" "$UNLOCK_DIR/id"
      echo "Unlocking a throwaway copy of ~/.ssh/id_ed25519 to re-key secrets.yaml..."
      ssh-keygen -p -q -N "" -f "$UNLOCK_DIR/id"
      SOPS_AGE_KEY="$(ssh-to-age -private-key -i "$UNLOCK_DIR/id")" "$@"
    }
  '';

  mkApp = name: text: {
    type = "app";
    program = "${
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = with pkgs; [
          nixos-rebuild-ng
          sops
          ssh-to-age
          openssh
          coreutils
          gnused
          gawk
          gnugrep
          git
          nix
          hostname-debian
        ];
        text = common + text;
      }
    }/bin/${name}";
  };
in
{
  update = mkApp "update" ''
    isolate_ssh_agent
    (cd "$ROOT" && nix flake update)
  '';

  switch = mkApp "switch" ''
    isolate_ssh_agent
    if [[ ''${#TARGET_HOSTS[@]} -gt 0 ]]; then
      run_multi_target switch
    else
      echo "Switching to configuration for $HOSTNAME..."
      nixos-rebuild switch --sudo --flake "$ROOT#$HOSTNAME"
      { i3-msg restart || swaymsg reload; } 2>/dev/null || true
    fi
  '';

  add-host = mkApp "add-host" ''
    host_key=/etc/ssh/ssh_host_ed25519_key
    sops_yaml="$ROOT/.sops.yaml"
    [[ "$HOSTNAME" =~ ^[a-z0-9-]+$ ]] || { echo "Error: bad hostname '$HOSTNAME'" >&2; exit 1; }

    if [[ ! -s "$host_key.pub" ]]; then
      echo "No $host_key; generating it..."
      sudo ssh-keygen -q -t ed25519 -N "" -f "$host_key"
    fi
    recipient="$(ssh-to-age < "$host_key.pub")"

    if grep -q "^  - &$HOSTNAME " "$sops_yaml"; then
      sed -i "s|^  - &$HOSTNAME .*|  - \&$HOSTNAME $recipient|" "$sops_yaml"
    else
      awk -v h="$HOSTNAME" -v r="$recipient" '
        { lines[NR] = $0 }
        /^  - &/ { lastkey = NR }
        /^          - \*/ { lastref = NR }
        END {
          for (i = 1; i <= NR; i++) {
            print lines[i]
            if (i == lastkey) print "  - &" h " " r
            if (i == lastref) print "          - *" h
          }
        }' "$sops_yaml" > "$sops_yaml.new"
      mv "$sops_yaml.new" "$sops_yaml"
    fi

    with_eva_age_key sops updatekeys -y "$ROOT/secrets.yaml"

    echo "$HOSTNAME is a decrypter; commit .sops.yaml and secrets.yaml, then nix run .#switch."
  '';

  remove-host = mkApp "remove-host" ''
    sops_yaml="$ROOT/.sops.yaml"
    [[ -n "$HOST_ARG" ]] || { echo "Error: remove-host needs an explicit hostname" >&2; exit 1; }
    [[ "$HOSTNAME" =~ ^[a-z0-9-]+$ ]] || { echo "Error: bad hostname '$HOSTNAME'" >&2; exit 1; }
    [[ "$HOSTNAME" != eva ]] || { echo "Error: eva is the re-keying identity, not a host" >&2; exit 1; }
    grep -q "^  - &$HOSTNAME " "$sops_yaml" || { echo "Error: $HOSTNAME is not in .sops.yaml" >&2; exit 1; }

    sed -i -e "/^  - &$HOSTNAME /d" -e "/^          - \*$HOSTNAME\$/d" "$sops_yaml"

    # rotate replaces the data key, so a saved copy of the old one stops working on new commits.
    rekey() { sops updatekeys -y "$1" && sops rotate -i "$1"; }
    with_eva_age_key rekey "$ROOT/secrets.yaml"

    echo "$HOSTNAME can no longer decrypt secrets.yaml; commit .sops.yaml and secrets.yaml."
    echo "Old commits still decrypt with its key: rotate the secret values themselves if it was compromised."
  '';
}
