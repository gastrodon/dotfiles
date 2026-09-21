#!/usr/bin/env bash
# Copy the contents of a running HashiCorp Vault into a fresh OpenBao instance.
#
# Why this exists: OpenBao is a fork of Vault that kept the HTTP API, so
# "migrating" is really a read-from-one/write-to-the-other loop. The interesting
# part is everything that must NOT move. Tokens, leases, secret_ids and
# cubbyholes are either credentials or per-token state: they get re-issued on
# the new server, never copied. What moves is durable config and KV data.
#
# DRY RUN BY DEFAULT. Nothing is written without --apply.
#
# Secrecy rules this script holds to, because its output is expected to be
# pasted into a ticket:
#   * secret *values* are never printed -- not in the plan, not in the summary,
#     not in an error. Paths, key names and counts only.
#   * error text is limited to Vault's own `.errors[]` array, never a raw
#     response body: the body of a KV read *is* the secret.
#   * no `set -x` anywhere, ever. It would echo tokens and payloads.
#   * comparisons use a digest salted with a fresh random value per run, so a
#     printed digest cannot be ground offline against a guessed secret value.
#     It is only meaningful within a single run's output.
#
# Credentials come from the environment and nowhere else. There is deliberately
# no default address: a baked-in default is how somebody eventually points this
# at the wrong (live) server by accident.
#
#   VAULT_ADDR   source, e.g. http://host:8200
#   VAULT_TOKEN  source token; needs read on the KV tree, sys/policies, sys/mounts
#                and the approle endpoints
#   BAO_ADDR     target
#   BAO_TOKEN    target token; needs write on the same, plus sys/mounts and
#                sys/auth if the mount or the approle method is missing
#
# OpenBao compatibility: every endpoint used here is a Vault endpoint, and they
# are assumed to work unchanged against BAO_ADDR because OpenBao forked from
# Vault and kept the API surface. That is an inference from the fork's lineage,
# not something checked against OpenBao's own documentation. The three places
# the assumption carries the most weight are flagged inline: sys/health,
# creating a kv-v2 mount through sys/mounts, and the approle endpoints.

set -euo pipefail

# Associative arrays and the `${arr[@]}` empty-array behaviour under `set -u`.
if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
  printf 'fatal: needs bash 4+, this is %s\n' "${BASH_VERSION:-unknown}" >&2
  exit 1
fi

usage() {
  cat <<'USAGE'
copy-vault-to-bao.sh -- copy a Vault's contents into a fresh OpenBao

  ./copy-vault-to-bao.sh            dry run: print the plan, write nothing
  ./copy-vault-to-bao.sh --apply    perform the writes

Options:
  --apply              actually write to the target (default: dry run)
  --kv-mount NAME      KV v2 mount to copy, used on both sides (default: secret)
  --no-copy-role-id    do not preserve approle role_ids on the target
  -h, --help           this text

Required environment -- no defaults, all four must be set:
  VAULT_ADDR  VAULT_TOKEN    source Vault
  BAO_ADDR    BAO_TOKEN      target OpenBao

Exit status: 0 clean, 1 refused before doing anything, 2 one or more items
failed or failed verification, 64 bad usage.
USAGE
}

APPLY=0
KV_MOUNT="secret"
COPY_ROLE_ID=1

while (( $# )); do
  case "$1" in
    --apply)            APPLY=1 ;;
    --kv-mount)         KV_MOUNT="${2:?--kv-mount needs a value}"; shift ;;
    --no-copy-role-id)  COPY_ROLE_ID=0 ;;
    -h|--help)          usage; exit 0 ;;
    *) printf 'unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 64 ;;
  esac
  shift
done
KV_MOUNT="${KV_MOUNT%/}"

# Built-in policies. `default` and `root` ship with every server; `default-ceiling`
# is likewise built in. They already exist on the target, and `root` is rejected
# outright if you try to write it, so all three are skipped rather than copied.
BUILTIN_POLICIES=(default root default-ceiling)

# ---------------------------------------------------------------- output ----

log()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'fatal: %s\n' "$*" >&2; exit 1; }

declare -a SUMMARY=()
FAILED=0

record() { SUMMARY+=("$(printf '%-10s %s' "$1" "$2")"); }
fail()   { FAILED=$(( FAILED + 1 )); printf '  FAILED: %s\n' "$*" >&2; record FAILED "$1"; }

# In dry run every mutating verb is reported as something that *would* happen,
# so a plan can never be misread as a completed action.
verb() { if (( APPLY )); then printf '%s' "$1"; else printf 'would %s' "$1"; fi; }

# ------------------------------------------------------------ preflight -----

for dep in curl jq sha256sum mktemp; do
  command -v "$dep" >/dev/null || die "needs ${dep} on PATH"
done
# The `vault` CLI is deliberately not a dependency: it is not installed on the
# machine this was written for, and everything below is plain HTTP anyway.

missing=()
for v in VAULT_ADDR VAULT_TOKEN BAO_ADDR BAO_TOKEN; do
  [[ -n "${!v:-}" ]] || missing+=("$v")
done
if (( ${#missing[@]} )); then
  die "unset or empty in the environment: ${missing[*]} -- this script never supplies a default for any of them"
fi

# Trailing slashes only: this is a guard against the obvious mistake, not a
# proof. Two different names for the same host would still get past it.
SRC_ADDR="${VAULT_ADDR%/}"
DST_ADDR="${BAO_ADDR%/}"
[[ "$SRC_ADDR" != "$DST_ADDR" ]] || die "VAULT_ADDR and BAO_ADDR are the same server (${SRC_ADDR}); refusing to copy a Vault onto itself"

umask 077
WORKDIR="$(mktemp -d)"
trap 'rm -rf -- "$WORKDIR"' EXIT

# Tokens are handed to curl through a file (`-H @file`, curl 7.55+) instead of
# the command line: argv is readable through /proc by anyone on the box, and
# this script expects a very privileged token. The files live in a 0700 dir and
# die with the trap.
printf 'X-Vault-Token: %s\nContent-Type: application/json\n' "$VAULT_TOKEN" > "${WORKDIR}/src.hdr"
printf 'X-Vault-Token: %s\nContent-Type: application/json\n' "$BAO_TOKEN"   > "${WORKDIR}/dst.hdr"

# Salt the comparison digests so that printing one leaks nothing: a low-entropy
# secret value could otherwise be confirmed by guessing it and hashing it. With
# a fresh salt per run, digests are comparable only against each other, within
# this run's output, which is all the operator needs them for.
RUN_SALT="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
digest() { printf '%s' "${RUN_SALT}${1}" | sha256sum | cut -c1-12; }

# ------------------------------------------------------------- HTTP ---------

API_CODE=""
API_BODY=""

# One call against one side. Sets API_CODE/API_BODY and always returns 0, so
# callers can branch on the status: 404 is a normal answer to "does this exist
# yet", not an error.
#
# Because it communicates through globals it must be called at statement level.
# Calling it inside $( ) puts it in a subshell and the results are lost; every
# call site below reads API_BODY on the next line instead.
api_raw() {
  # `endpoint` rather than `path`: harmless in bash, but `path` is bound to
  # PATH in zsh, and a stray `zsh copy-vault-to-bao.sh` would erase PATH on the
  # first call and fail with "command not found: curl".
  local side="$1" method="$2" endpoint="$3" body="${4-}"
  local addr hdr out
  local -a args

  case "$side" in
    src) addr="$SRC_ADDR"; hdr="${WORKDIR}/src.hdr" ;;
    dst) addr="$DST_ADDR"; hdr="${WORKDIR}/dst.hdr" ;;
    *)   die "internal error: unknown side '${side}'" ;;
  esac

  args=(--silent --show-error
        --request "$method"
        --header "@${hdr}"
        --connect-timeout 5 --max-time 30
        --write-out '\n%{http_code}')

  if [[ -n "$body" ]]; then
    printf '%s' "$body" > "${WORKDIR}/body.json"
    args+=(--data-binary "@${WORKDIR}/body.json")
  fi

  # curl's own failures -- refused, DNS, TLS -- exit non-zero with no status
  # code. Report those as 000 so a caller sees "unreachable" rather than an
  # empty status it has no case for.
  if ! out="$(curl "${args[@]}" "${addr}/v1/${endpoint}" 2>"${WORKDIR}/curl.err")"; then
    API_CODE="000"
    API_BODY="$(cat "${WORKDIR}/curl.err")"
  else
    API_CODE="${out##*$'\n'}"
    API_BODY="${out%$'\n'*}"
  fi

  # Do not leave a request body -- which may be secret material -- sitting in
  # the temp dir any longer than the call it belonged to.
  [[ -z "$body" ]] || : > "${WORKDIR}/body.json"
  return 0
}

api_2xx() { [[ "$API_CODE" == 2?? ]]; }

# The only thing ever quoted out of a response. `.errors[]` is Vault's error
# envelope and carries messages, never stored data; a raw body could be a
# secret read that happened to come back with an odd status.
api_errors() {
  local e
  # The one branch that prints API_BODY verbatim, and it is safe only because
  # of an invariant set in api_raw: on 000 the body was never a response, it is
  # curl's own stderr ("connection refused", "certificate problem"). Do not
  # widen this branch to other statuses.
  if [[ "$API_CODE" == "000" ]]; then
    printf '%s' "${API_BODY//$'\n'/ }"
    return 0
  fi
  e="$(jq -r '.errors[]? // empty' <<<"$API_BODY" 2>/dev/null | tr '\n' ';' || true)"
  printf '%s' "${e:-(no error detail)}"
}

# ------------------------------------------------- server / mount checks ----

# sys/health deliberately does not go through a 2xx-only wrapper: it signals
# state through the status code on purpose (uninitialised, sealed and standby
# each have their own, and the exact table has moved between versions). The
# booleans in the body are the dependable signal, so read those and ignore the
# status line. Assumed identical on OpenBao -- same endpoint, same fork.
check_server() {
  local side="$1" label="$2" addr="$3"
  local init sealed pols

  api_raw "$side" GET 'sys/health?standbyok=true&perfstandbyok=true'
  [[ "$API_CODE" != "000" ]] || die "${label} (${addr}) is unreachable: $(api_errors)"

  # NOT `.initialized? // empty`. jq's `//` returns its right-hand side when
  # the left is null OR FALSE, so `.sealed // empty` yields empty for a server
  # that is simply unsealed -- i.e. the healthy case reads as "not a Vault
  # API" and this function dies on exactly the servers it should accept.
  # (Measured 2026-09-21 against Vault 2.1.0, `sealed: false`.) `has()` asks
  # the question actually intended: is the field present at all.
  init="$(jq -r 'if has("initialized") then (.initialized|tostring) else empty end'   <<<"$API_BODY" 2>/dev/null || true)"
  sealed="$(jq -r 'if has("sealed")      then (.sealed|tostring)      else empty end' <<<"$API_BODY" 2>/dev/null || true)"
  [[ -n "$init" && -n "$sealed" ]] || die "${label} (${addr}) did not answer sys/health like a Vault or OpenBao API (HTTP ${API_CODE})"
  [[ "$init"   == "true"  ]] || die "${label} (${addr}) is not initialised"
  [[ "$sealed" == "false" ]] || die "${label} (${addr}) is sealed"

  api_raw "$side" GET 'auth/token/lookup-self'
  api_2xx || die "${label} (${addr}) rejected the token (HTTP ${API_CODE}): $(api_errors)"
  # This response contains the token itself in .data.id. Take the policy names
  # and nothing else; never echo this body.
  pols="$(jq -r '(.data.policies // []) | join(",")' <<<"$API_BODY" 2>/dev/null || true)"

  info "$(printf '%-7s %-34s initialised, unsealed, token ok (policies: %s)' "$label" "$addr" "${pols:-unknown}")"
}

MOUNT_STATE=""
MOUNT_DETAIL=""

# absent | kv2 | wrong. A kv v1 mount answering at the same name is the
# dangerous case: writes to <mount>/data/<path> would land as literal secrets
# under a "data" prefix instead of being v2 records, so that is a hard stop
# rather than something to work around.
check_kv_mount() {
  local side="$1" label="$2"
  local m type version

  api_raw "$side" GET 'sys/mounts'
  api_2xx || die "${label}: cannot read sys/mounts (HTTP ${API_CODE}): $(api_errors) -- the token needs enough privilege to list mounts"

  # Vault answers sys/mounts in both the modern wrapped shape and a legacy
  # flat one; take .data when it is there and the root object otherwise.
  m="$(jq -c --arg k "${KV_MOUNT}/" '(.data // .) | .[$k] // empty' <<<"$API_BODY")"
  if [[ -z "$m" ]]; then
    MOUNT_STATE="absent"; MOUNT_DETAIL=""
    return 0
  fi

  type="$(jq -r '.type // ""' <<<"$m")"
  version="$(jq -r '.options.version // ""' <<<"$m")"
  if [[ "$type" == "kv" && "$version" == "2" ]]; then
    MOUNT_STATE="kv2"; MOUNT_DETAIL=""
  else
    MOUNT_STATE="wrong"; MOUNT_DETAIL="type=${type:-?} version=${version:-1}"
  fi
}

# --------------------------------------------------------------- kv walk ----

declare -a KV_LEAVES=()

# Recursive listing of a kv v2 tree. Two things worth knowing:
#   * listing goes through metadata/, reading through data/. That split is the
#     whole practical difference between kv v1 and v2 at the API level.
#   * a name can be both a leaf and a directory: "claude" holding data while
#     "claude/" holds children. They are listed as two separate entries, one
#     with a trailing slash, so handling them independently is already correct
#     and needs no special case.
# Listing is done as GET ?list=true rather than the LIST method because plain
# GET survives proxies and curl builds that dislike an unusual verb.
# Path segments are sent unencoded: the tree this targets is plain lowercase
# names. A segment containing a space, '#' or '?' would need URL encoding.
kv_walk() {
  local prefix="$1"
  local entry
  local -a keys=()

  api_raw src GET "${KV_MOUNT}/metadata/${prefix}?list=true"
  case "$API_CODE" in
    2??) : ;;
    404) return 0 ;;   # empty or absent subtree: nothing under it to copy
    *)   die "listing ${KV_MOUNT}/${prefix} failed (HTTP ${API_CODE}): $(api_errors)" ;;
  esac

  # Read the listing out before recursing: the recursive call overwrites
  # API_BODY, so anything still needed from this level has to be captured now.
  mapfile -t keys < <(jq -r '.data.keys[]?' <<<"$API_BODY")

  (( ${#keys[@]} )) || return 0
  for entry in "${keys[@]}"; do
    if [[ "$entry" == */ ]]; then
      kv_walk "${prefix}${entry}"
    else
      KV_LEAVES+=("${prefix}${entry}")
    fi
  done
}

# ============================================================== preflight ====

log "== preflight =="
if (( APPLY )); then
  log "  mode    APPLY -- writes will be made to the target"
else
  log "  mode    dry run -- nothing will be written (pass --apply to do it for real)"
fi
check_server src source "$SRC_ADDR"
check_server dst target "$DST_ADDR"

check_kv_mount src source
case "$MOUNT_STATE" in
  kv2)    info "source  ${KV_MOUNT}/ is kv v2" ;;
  absent) die "source has no ${KV_MOUNT}/ mount -- nothing to copy (use --kv-mount if it is named differently)" ;;
  wrong)  die "source ${KV_MOUNT}/ is not kv v2 (${MOUNT_DETAIL}); this script only understands kv v2" ;;
  *)      die "internal error: unexpected source mount state '${MOUNT_STATE}'" ;;
esac

check_kv_mount dst target
TARGET_MOUNT_STATE="$MOUNT_STATE"
case "$TARGET_MOUNT_STATE" in
  kv2)    info "target  ${KV_MOUNT}/ is kv v2 already" ;;
  absent) info "target  ${KV_MOUNT}/ is absent" ;;
  wrong)  die "target ${KV_MOUNT}/ exists but is not kv v2 (${MOUNT_DETAIL}) -- writing kv v2 paths into it would corrupt it. Remove it, or point --kv-mount elsewhere." ;;
  *)      die "internal error: unexpected target mount state '${TARGET_MOUNT_STATE}'" ;;
esac
log ""

# ==================================================== phase 1: kv mount =====

log "== phase 1: kv mount =="

# Whether the mount is on the target *now*, as opposed to whether it is planned.
# Phase 2 needs the distinction: in a dry run against a fresh server the mount
# is still absent when the secrets are compared, and reading through a mount
# that does not exist is not a question worth asking.
DST_MOUNT_READY=0

if [[ "$TARGET_MOUNT_STATE" == "kv2" ]]; then
  info "${KV_MOUNT}/ exists as kv v2, nothing to do"
  record unchanged "mount ${KV_MOUNT}/"
  DST_MOUNT_READY=1
else
  info "$(verb create) mount ${KV_MOUNT}/ as kv v2"
  if (( APPLY )); then
    # options.version=2 rather than type=kv-v2: the options form is the one
    # both Vault and OpenBao have always accepted. Assumed to hold on OpenBao.
    api_raw dst POST "sys/mounts/${KV_MOUNT}" '{"type":"kv","options":{"version":"2"}}'
    if api_2xx; then
      record created "mount ${KV_MOUNT}/"

      # WAIT FOR THE MOUNT TO ACTUALLY SERVE. Creating a kv v2 mount kicks off
      # an asynchronous "Upgrading from non-versioned to versioned data" pass,
      # and reads that land inside that window come back HTTP 400 with exactly
      # that sentence -- not an error, just "not yet". Measured 2026-09-21
      # against OpenBao 2.6.2: nine consecutive reads failed this way and the
      # tenth succeeded, so the window is real and roughly a second wide.
      #
      # Poll a read that is expected to 404 on a healthy empty mount. A 404 is
      # the success signal here: the mount answered. Anything else means it is
      # still upgrading (or genuinely broken, which the timeout surfaces).
      mount_wait=0
      until (( mount_wait >= 30 )); do
        api_raw dst GET "${KV_MOUNT}/data/.readiness-probe"
        [[ "$API_CODE" != "400" ]] && break
        sleep 1
        mount_wait=$(( mount_wait + 1 ))
      done
      if (( mount_wait > 0 )); then
        info "waited ${mount_wait}s for ${KV_MOUNT}/ to finish initialising"
      fi
      (( mount_wait < 30 )) || die "${KV_MOUNT}/ still reports it is upgrading after 30s"

      DST_MOUNT_READY=1
    else
      fail "creating mount ${KV_MOUNT}/ (HTTP ${API_CODE}): $(api_errors)"
      die "cannot continue without the destination mount"
    fi
  else
    record "would create" "mount ${KV_MOUNT}/"
  fi
fi
log ""

# ===================================================== phase 2: secrets =====

log "== phase 2: secrets =="
kv_walk ""

declare -A SRC_DIGEST=()      # leaf -> digest of the source data object
declare -a WROTE_LEAVES=()    # leaves that were written, for the verify pass

if (( ${#KV_LEAVES[@]} == 0 )); then
  info "no secrets found under ${KV_MOUNT}/"
else
  info "${#KV_LEAVES[@]} secret path(s) found under ${KV_MOUNT}/"
  for leaf in "${KV_LEAVES[@]}"; do
    api_raw src GET "${KV_MOUNT}/data/${leaf}"
    if [[ "$API_CODE" == "404" ]]; then
      # Listed under metadata/ but with no live version: soft-deleted or
      # destroyed. There is nothing to copy and recreating it would resurrect
      # something that was deliberately removed.
      info "${leaf}: no current version on the source, skipping"
      record skipped "secret ${KV_MOUNT}/${leaf} (no current version)"
      continue
    fi
    if ! api_2xx; then
      fail "secret ${KV_MOUNT}/${leaf}: source read failed (HTTP ${API_CODE}): $(api_errors)"
      continue
    fi
    if ! jq -e '.data.data != null' <<<"$API_BODY" >/dev/null 2>&1; then
      info "${leaf}: no data object on the source, skipping"
      record skipped "secret ${KV_MOUNT}/${leaf} (no data)"
      continue
    fi

    src_data="$(jq -cS '.data.data' <<<"$API_BODY")"
    src_keys="$(jq -r 'keys | join(", ")' <<<"$src_data")"
    src_dg="$(digest "$src_data")"
    SRC_DIGEST["$leaf"]="$src_dg"

    # custom_metadata is not copied. It is rarely used and copying it doubles
    # the write surface, but silently dropping it would be data loss, so say so
    # when there is any. The count only -- the values are not ours to print.
    api_raw src GET "${KV_MOUNT}/metadata/${leaf}"
    if api_2xx; then
      cm="$(jq -r '(.data.custom_metadata // {}) | length' <<<"$API_BODY" 2>/dev/null || echo 0)"
      (( cm == 0 )) || warn "${leaf}: ${cm} custom_metadata entr(y/ies) on the source are NOT copied"
    fi

    if (( ! DST_MOUNT_READY )); then
      # Dry run against a server that has no such mount yet: every leaf is a
      # create by definition. Asking anyway would mean relying on a mount that
      # does not exist answering 404 rather than 403, which is a detail that
      # varies with the token's policy -- and a 403 here would mark every
      # secret FAILED in what is supposed to be a harmless plan.
      action="create"
    else
      api_raw dst GET "${KV_MOUNT}/data/${leaf}"
      if [[ "$API_CODE" == "404" ]]; then
        action="create"
      elif api_2xx && jq -e '.data.data != null' <<<"$API_BODY" >/dev/null 2>&1; then
        dst_dg="$(digest "$(jq -cS '.data.data' <<<"$API_BODY")")"
        if [[ "$dst_dg" == "$src_dg" ]]; then
          action="none"
        else
          action="update"
        fi
      elif api_2xx; then
        action="create"
      else
        fail "secret ${KV_MOUNT}/${leaf}: target read failed (HTTP ${API_CODE}): $(api_errors)"
        continue
      fi
    fi

    case "$action" in
      none)
        info "${leaf}: identical on the target [${src_dg}] (keys: ${src_keys})"
        record unchanged "secret ${KV_MOUNT}/${leaf}"
        ;;
      create|update)
        if [[ "$action" == "update" ]]; then
          info "${leaf}: DIFFERS on the target -- $(verb update) it, adding a new kv version (keys: ${src_keys}) [${src_dg}]"
        else
          info "${leaf}: absent on the target -- $(verb create) it (keys: ${src_keys}) [${src_dg}]"
        fi
        if (( APPLY )); then
          # No `options.cas`: there are no concurrent writers during a
          # migration, and the read-above-then-write-here check is what makes
          # a re-run converge instead of piling up identical kv versions.
          if api_raw dst POST "${KV_MOUNT}/data/${leaf}" "$(jq -cn --argjson d "$src_data" '{data:$d}')" && api_2xx; then
            record "${action}d" "secret ${KV_MOUNT}/${leaf}"
            WROTE_LEAVES+=("$leaf")
          else
            fail "secret ${KV_MOUNT}/${leaf}: write failed (HTTP ${API_CODE}): $(api_errors)"
          fi
        else
          record "would ${action}" "secret ${KV_MOUNT}/${leaf}"
        fi
        ;;
      *) die "internal error: unexpected action '${action}'" ;;
    esac
    unset src_data   # keep secret material out of the environment between loops
  done
fi
log ""

# ==================================================== phase 3: policies =====

log "== phase 3: custom policies =="
api_raw src GET 'sys/policies/acl?list=true'
declare -a POLICIES=()
case "$API_CODE" in
  2??) mapfile -t POLICIES < <(jq -r '.data.keys[]?' <<<"$API_BODY") ;;
  404) : ;;
  *)   die "listing source policies failed (HTTP ${API_CODE}): $(api_errors)" ;;
esac

declare -a WROTE_POLICIES=()
declare -A SRC_POLICY_DIGEST=()
copied_any=0
if (( ${#POLICIES[@]} )); then
  for pol in "${POLICIES[@]}"; do
    skip=0
    for b in "${BUILTIN_POLICIES[@]}"; do
      [[ "$pol" == "$b" ]] && { skip=1; break; }
    done
    if (( skip )); then
      info "${pol}: built-in, skipping"
      record skipped "policy ${pol} (built-in)"
      continue
    fi
    copied_any=1

    api_raw src GET "sys/policies/acl/${pol}"
    if ! api_2xx; then
      fail "policy ${pol}: source read failed (HTTP ${API_CODE}): $(api_errors)"
      continue
    fi
    src_pol="$(jq -r '.data.policy // ""' <<<"$API_BODY")"
    if [[ -z "${src_pol//[[:space:]]/}" ]]; then
      info "${pol}: empty on the source, skipping"
      record skipped "policy ${pol} (empty)"
      continue
    fi
    # Compare with trailing whitespace stripped from both sides: a server that
    # normalises the stored text would otherwise make every run look dirty.
    src_pol_cmp="${src_pol%"${src_pol##*[![:space:]]}"}"
    SRC_POLICY_DIGEST["$pol"]="$(digest "$src_pol_cmp")"

    api_raw dst GET "sys/policies/acl/${pol}"
    if [[ "$API_CODE" == "404" ]]; then
      action="create"
    elif api_2xx; then
      dst_pol="$(jq -r '.data.policy // ""' <<<"$API_BODY")"
      dst_pol_cmp="${dst_pol%"${dst_pol##*[![:space:]]}"}"
      if [[ "$src_pol_cmp" == "$dst_pol_cmp" ]]; then action="none"; else action="update"; fi
    else
      fail "policy ${pol}: target read failed (HTTP ${API_CODE}): $(api_errors)"
      continue
    fi

    case "$action" in
      none)
        info "${pol}: identical on the target"
        record unchanged "policy ${pol}"
        ;;
      create|update)
        info "${pol}: $(verb "$action") ($(wc -l <<<"$src_pol_cmp" | tr -d ' ') lines of HCL)"
        if (( APPLY )); then
          if api_raw dst PUT "sys/policies/acl/${pol}" "$(jq -cn --arg p "$src_pol" '{policy:$p}')" && api_2xx; then
            record "${action}d" "policy ${pol}"
            WROTE_POLICIES+=("$pol")
          else
            fail "policy ${pol}: write failed (HTTP ${API_CODE}): $(api_errors)"
          fi
        else
          record "would ${action}" "policy ${pol}"
        fi
        ;;
      *) die "internal error: unexpected action '${action}'" ;;
    esac
  done
fi
(( copied_any )) || info "no custom policies on the source (built-ins aside)"
log ""

# ===================================================== phase 4: approle =====

log "== phase 4: approle roles =="

# This phase runs last on purpose: a role names its token_policies, and a role
# written before those policies exist is a role pointing at nothing. Phase 3
# has already put them there.

# Is approle enabled on the source at all? If not there is nothing in this
# phase to do, and the target should not have it turned on speculatively.
api_raw src GET 'sys/auth'
SRC_HAS_APPROLE=0
if api_2xx; then
  jq -e '(.data // .) | has("approle/")' <<<"$API_BODY" >/dev/null 2>&1 && SRC_HAS_APPROLE=1
else
  warn "cannot read source sys/auth (HTTP ${API_CODE}): $(api_errors) -- assuming no approle"
fi

declare -a ROLES=()
declare -A SRC_ROLE_CFG=()
declare -a WROTE_ROLES=()
declare -a WROTE_ROLE_IDS=()
declare -A SRC_ROLE_ID_DIGEST=()   # digest only: the value itself is not kept around

if (( ! SRC_HAS_APPROLE )); then
  info "approle is not enabled on the source, nothing to copy"
else
  api_raw src GET 'auth/approle/role?list=true'
  case "$API_CODE" in
    2??) mapfile -t ROLES < <(jq -r '.data.keys[]?' <<<"$API_BODY") ;;
    404) : ;;   # method enabled, no roles defined
    *)   fail "listing source approle roles (HTTP ${API_CODE}): $(api_errors)" ;;
  esac

  if (( ${#ROLES[@]} == 0 )); then
    info "approle is enabled on the source but has no roles"
  else
    # The auth method has to exist on the target before a role can be written
    # to it. Enabling an already-enabled method is an error rather than a
    # no-op, hence the check first. Assumed to behave the same on OpenBao.
    api_raw dst GET 'sys/auth'
    if ! api_2xx; then
      die "cannot read target sys/auth (HTTP ${API_CODE}): $(api_errors)"
    fi
    DST_APPROLE_READY=0
    if jq -e '(.data // .) | has("approle/")' <<<"$API_BODY" >/dev/null 2>&1; then
      info "approle auth is already enabled on the target"
      record unchanged "auth method approle/"
      DST_APPROLE_READY=1
    else
      info "$(verb enable) approle auth on the target"
      if (( APPLY )); then
        if api_raw dst POST 'sys/auth/approle' '{"type":"approle"}' && api_2xx; then
          record enabled "auth method approle/"
          DST_APPROLE_READY=1
        else
          fail "enabling approle on the target (HTTP ${API_CODE}): $(api_errors)"
          die "cannot write roles without the auth method"
        fi
      else
        record "would enable" "auth method approle/"
      fi
    fi

    for role in "${ROLES[@]}"; do
      api_raw src GET "auth/approle/role/${role}"
      if ! api_2xx; then
        fail "approle role ${role}: source read failed (HTTP ${API_CODE}): $(api_errors)"
        continue
      fi
      # Drop two fields before replaying the config:
      #   policies  -- a deprecated alias of token_policies; sending both is
      #                redundant and some versions object.
      #   role_id   -- an identifier with its own endpoint, handled below.
      src_cfg="$(jq -cS 'del(.policies, .role_id)' <<<"$(jq -c '.data // {}' <<<"$API_BODY")")"
      SRC_ROLE_CFG["$role"]="$src_cfg"
      fields="$(jq -r 'keys | join(", ")' <<<"$src_cfg")"

      if (( ! DST_APPROLE_READY )); then
        # As in phase 2: dry run, the auth method is not enabled on the target
        # yet, so the role cannot exist and there is nothing to read.
        action="create"
        body_cfg="$src_cfg"
      else
        api_raw dst GET "auth/approle/role/${role}"
        if [[ "$API_CODE" == "404" ]]; then
          action="create"
          body_cfg="$src_cfg"
        elif api_2xx; then
          dst_cfg="$(jq -cS 'del(.policies, .role_id)' <<<"$(jq -c '.data // {}' <<<"$API_BODY")")"
          # Compare over the source's fields only. The two servers may report
          # different sets of defaults, and a field the source never set is not
          # a difference worth rewriting -- or worth failing verification over.
          diff_fields="$(jq -rn --argjson s "$src_cfg" --argjson t "$dst_cfg" '[$s|keys[]|select($s[.] != $t[.])] | join(", ")')"
          if [[ -z "$diff_fields" ]]; then
            action="none"
          else
            action="update"
            # local_secret_ids can only be set when the role is created; sending
            # it on an update is rejected, so strip it from the update body.
            body_cfg="$(jq -c 'del(.local_secret_ids)' <<<"$src_cfg")"
          fi
        else
          fail "approle role ${role}: target read failed (HTTP ${API_CODE}): $(api_errors)"
          continue
        fi
      fi

      case "$action" in
        none)
          info "${role}: config already matches on the target (fields: ${fields})"
          record unchanged "approle role ${role}"
          ;;
        create|update)
          if [[ "$action" == "update" ]]; then
            info "${role}: config differs on the target in: ${diff_fields} -- $(verb update)"
          else
            info "${role}: absent on the target -- $(verb create) (fields: ${fields})"
          fi
          if (( APPLY )); then
            if api_raw dst POST "auth/approle/role/${role}" "$body_cfg" && api_2xx; then
              record "${action}d" "approle role ${role}"
              WROTE_ROLES+=("$role")
            else
              fail "approle role ${role}: write failed (HTTP ${API_CODE}): $(api_errors)"
              continue
            fi
          else
            record "would ${action}" "approle role ${role}"
          fi
          ;;
        *) die "internal error: unexpected action '${action}'" ;;
      esac

      # role_id is an identifier, not a credential -- on its own it authenticates
      # nothing, which is why it is the half of the pair that gets checked into
      # config while the secret_id does not. Preserving it means anything already
      # configured with the old role_id keeps working against the new server.
      # Its value is still never printed. --no-copy-role-id opts out and lets
      # the target keep the one it generated.
      if (( COPY_ROLE_ID )); then
        api_raw src GET "auth/approle/role/${role}/role-id"
        if ! api_2xx; then
          fail "approle role ${role}: source role-id read failed (HTTP ${API_CODE}): $(api_errors)"
        else
          src_rid="$(jq -r '.data.role_id // empty' <<<"$API_BODY")"
          api_raw dst GET "auth/approle/role/${role}/role-id"
          dst_rid=""
          api_2xx && dst_rid="$(jq -r '.data.role_id // empty' <<<"$API_BODY")"
          if [[ -n "$src_rid" && "$src_rid" == "$dst_rid" ]]; then
            info "${role}: role_id already matches the source"
            record unchanged "approle role_id ${role}"
          elif [[ -z "$src_rid" ]]; then
            fail "approle role_id ${role}: source returned no role_id"
          else
            info "${role}: $(verb set) role_id to the source's (value not shown)"
            if (( APPLY )); then
              if api_raw dst POST "auth/approle/role/${role}/role-id" "$(jq -cn --arg r "$src_rid" '{role_id:$r}')" && api_2xx; then
                record set "approle role_id ${role}"
                SRC_ROLE_ID_DIGEST["$role"]="$(digest "$src_rid")"
                WROTE_ROLE_IDS+=("$role")
              else
                fail "approle role_id ${role}: write failed (HTTP ${API_CODE}): $(api_errors)"
              fi
            else
              record "would set" "approle role_id ${role}"
            fi
          fi
          unset src_rid dst_rid
        fi
      else
        info "${role}: role_id left as the target generated it (--no-copy-role-id)"
        record skipped "approle role_id ${role} (--no-copy-role-id)"
      fi

      # secret_ids are never copied, under any flag. They are bearer
      # credentials: a copied one is the same credential live in two places,
      # and the source's are about to be decommissioned anyway. Issue fresh
      # ones on the target with:
      #   POST ${BAO_ADDR}/v1/auth/approle/role/${role}/secret-id
      info "${role}: secret_ids NOT copied (bearer credentials) -- re-issue them on the target"
      record skipped "approle secret_ids for ${role} (re-issue on target)"
    done
  fi
fi
log ""

# ==================================================== verification pass =====

log "== verification =="
if (( ! APPLY )); then
  info "dry run: nothing was written, so there is nothing to read back."
  info "The comparisons above are the check -- every line reading 'identical'"
  info "or 'already matches' is source and target agreeing right now."
else
  verified=0
  vfailed=0

  for leaf in ${WROTE_LEAVES[@]+"${WROTE_LEAVES[@]}"}; do
    api_raw dst GET "${KV_MOUNT}/data/${leaf}"
    if ! api_2xx; then
      printf '  MISMATCH: secret %s/%s could not be read back (HTTP %s): %s\n' "$KV_MOUNT" "$leaf" "$API_CODE" "$(api_errors)" >&2
      vfailed=$(( vfailed + 1 )); continue
    fi
    back_dg="$(digest "$(jq -cS '.data.data // {}' <<<"$API_BODY")")"
    if [[ "$back_dg" == "${SRC_DIGEST[$leaf]}" ]]; then
      verified=$(( verified + 1 ))
    else
      printf '  MISMATCH: secret %s/%s read back as [%s], source is [%s]\n' "$KV_MOUNT" "$leaf" "$back_dg" "${SRC_DIGEST[$leaf]}" >&2
      vfailed=$(( vfailed + 1 ))
    fi
  done

  for pol in ${WROTE_POLICIES[@]+"${WROTE_POLICIES[@]}"}; do
    api_raw dst GET "sys/policies/acl/${pol}"
    if ! api_2xx; then
      printf '  MISMATCH: policy %s could not be read back (HTTP %s): %s\n' "$pol" "$API_CODE" "$(api_errors)" >&2
      vfailed=$(( vfailed + 1 )); continue
    fi
    back_pol="$(jq -r '.data.policy // ""' <<<"$API_BODY")"
    back_cmp="${back_pol%"${back_pol##*[![:space:]]}"}"
    if [[ "$(digest "$back_cmp")" == "${SRC_POLICY_DIGEST[$pol]}" ]]; then
      verified=$(( verified + 1 ))
    else
      printf '  MISMATCH: policy %s read back different from the source\n' "$pol" >&2
      vfailed=$(( vfailed + 1 ))
    fi
  done

  for role in ${WROTE_ROLES[@]+"${WROTE_ROLES[@]}"}; do
    api_raw dst GET "auth/approle/role/${role}"
    if ! api_2xx; then
      printf '  MISMATCH: approle role %s could not be read back (HTTP %s): %s\n' "$role" "$API_CODE" "$(api_errors)" >&2
      vfailed=$(( vfailed + 1 )); continue
    fi
    back_cfg="$(jq -cS 'del(.policies, .role_id)' <<<"$(jq -c '.data // {}' <<<"$API_BODY")")"

    # Three outcomes, not two. A field the source has and the target does not
    # report back is only a problem if it CARRIED something: OpenBao forked at
    # Vault 1.14 and does not implement every field Vault 2.x added, so it
    # drops those on write and omits them on read. Measured 2026-09-21:
    # `alias_metadata` is `{}` on Vault 2.1.0 and absent on OpenBao 2.6.2.
    # Flagging that as a mismatch trains the reader to ignore the mismatch
    # line, which is worse than not checking at all.
    #
    #   differing  present on both, values disagree     -- a real failure
    #   lost       absent on target, non-empty on source -- a real failure
    #   dropped    absent on target, empty on source     -- a note
    role_differing="$(jq -rn --argjson s "${SRC_ROLE_CFG[$role]}" --argjson t "$back_cfg" \
      '[$s|keys[]| . as $k | select(($t|has($k)) and ($s[$k] != $t[$k]))] | join(", ")')"
    role_lost="$(jq -rn --argjson s "${SRC_ROLE_CFG[$role]}" --argjson t "$back_cfg" \
      '[$s|keys[]| . as $k | select(($t|has($k)|not) and (($s[$k]|tostring) as $v | $v != "{}" and $v != "[]" and $v != "" and $v != "null"))] | join(", ")')"
    role_dropped="$(jq -rn --argjson s "${SRC_ROLE_CFG[$role]}" --argjson t "$back_cfg" \
      '[$s|keys[]| . as $k | select(($t|has($k)|not) and (($s[$k]|tostring) as $v | $v == "{}" or $v == "[]" or $v == "" or $v == "null"))] | join(", ")')"

    [[ -z "$role_dropped" ]] || \
      printf '  note: approle role %s -- target does not implement (empty on source, nothing lost): %s\n' "$role" "$role_dropped"

    if [[ -z "$role_differing" && -z "$role_lost" ]]; then
      verified=$(( verified + 1 ))
    else
      [[ -z "$role_differing" ]] || printf '  MISMATCH: approle role %s read back differing in: %s\n' "$role" "$role_differing" >&2
      [[ -z "$role_lost" ]]      || printf '  MISMATCH: approle role %s lost non-empty field(s) on the target: %s\n' "$role" "$role_lost" >&2
      vfailed=$(( vfailed + 1 ))
    fi
  done

  for role in ${WROTE_ROLE_IDS[@]+"${WROTE_ROLE_IDS[@]}"}; do
    api_raw dst GET "auth/approle/role/${role}/role-id"
    if ! api_2xx; then
      printf '  MISMATCH: approle role_id %s could not be read back (HTTP %s): %s\n' "$role" "$API_CODE" "$(api_errors)" >&2
      vfailed=$(( vfailed + 1 )); continue
    fi
    if [[ "$(digest "$(jq -r '.data.role_id // empty' <<<"$API_BODY")")" == "${SRC_ROLE_ID_DIGEST[$role]}" ]]; then
      verified=$(( verified + 1 ))
    else
      printf '  MISMATCH: approle role_id %s did not take on the target\n' "$role" >&2
      vfailed=$(( vfailed + 1 ))
    fi
  done

  info "${verified} item(s) read back and matched, ${vfailed} mismatched"
  # Only the items this run actually wrote are re-read here. Anything reported
  # as unchanged above was compared against the target at copy time, which is
  # the same check -- it is not unverified, just already done.
  FAILED=$(( FAILED + vfailed ))
fi
log ""

# =========================================================== not copied =====

log "== deliberately not copied =="
info "secret_ids            bearer credentials; re-issue on the target"
info "tokens and leases     per-session state; clients re-authenticate"
info "cubbyhole/            per-token by construction, unreadable by anyone else"
info "identity/ entities    not carried by this script"
info "sys/ and audit config target's own configuration, not the source's"
info "kv version history    only the current version of each secret is copied"
info "custom_metadata       not copied; a warning is printed wherever it exists"
log ""

# =============================================================== summary ====

log "== summary =="
if (( ${#SUMMARY[@]} == 0 )); then
  info "nothing to report"
else
  printf '  %s\n' "${SUMMARY[@]}"
fi
log ""

if (( FAILED )); then
  log "${FAILED} item(s) failed or failed verification -- see the messages above."
  exit 2
fi
if (( APPLY )); then
  log "All items succeeded and verified."
  log "Remember: no secret_ids were copied. Issue fresh ones on the target before"
  log "anything tries to authenticate against it."
else
  log "Dry run complete. Nothing was written. Re-run with --apply to do it."
fi
exit 0
