# Non-interactive entry point shared by the app: `status` prints JSON, `apply` brings modules to a wanted state.

conf_values() {
  [[ -f $RUNTIME/tahoe.conf ]] || return 0
  # shellcheck disable=SC1091
  (source "$RUNTIME/tahoe.conf" && printf '%s\n' "${VARIANT:-}" "${ACCENT:-}" "${BG_LIGHT:-}" "${BG_DARK:-}" "${PLYMOUTH_LOGO:-}")
}

# installs from before the app have no VARIANT in tahoe.conf: match the accent
variant_for_accent() {
  local f
  for f in "$REPO_DIR"/variants/*.conf; do
    grep -qx "ACCENT=$1" "$f" && { basename "$f" .conf; return 0; }
  done
}

current_variant() {
  local v=()
  mapfile -t v < <(conf_values)
  [[ -n ${v[0]:-} ]] && { echo "${v[0]}"; return 0; }
  [[ -n ${v[1]:-} ]] && variant_for_accent "${v[1]}"
  return 0
}

engine_status() {
  local id conf=() pairs=()
  mapfile -t conf < <(conf_values)
  for id in "${MODULES[@]}"; do pairs+=("$id=$("mod_${id}_status")"); done
  python3 -I -c '
import json, sys
variant, light, dark, logo, session, *mods = sys.argv[1:]
print(json.dumps({
    "variant": variant or None, "bg_light": light or None, "bg_dark": dark or None, "logo": logo or None,
    "session": session, "modules": dict(m.split("=", 1) for m in mods),
}))' "$(current_variant)" "${conf[2]:-}" "${conf[3]:-}" "${conf[4]:-}" "${XDG_SESSION_TYPE:-x11}" "${pairs[@]}"
}

valid_module() {
  local id=$1 value=$2 m
  for m in "${MODULES[@]}"; do
    [[ $m == "$id" ]] || continue
    [[ $id == launcher ]] && [[ " ${LAUNCHER_CHOICES[*]} " == *" $value "* ]] && return 0
    [[ $id != launcher && $value =~ ^(on|off)$ ]] && return 0
  done
  return 1
}

# errexit is ignored inside functions called from `||` or `if`, so each module runs in a subshell
# called as a plain statement; the result goes to STRICT_RC
run_strict() {
  local had_e=false
  [[ $- == *e* ]] && had_e=true
  set +e
  (set -eE; trap 'echo "Failed: $BASH_COMMAND (exit $?)"; trap - ERR' ERR; "$@")
  STRICT_RC=$?
  $had_e && set -e
  return 0
}

module_action() {
  local id=$1 action=$2
  if [[ $id == launcher ]]; then
    mod_launcher_set "$3"
  else
    "mod_${id}_$action"
  fi
}

# $1 id, $2 install|remove, $3 launcher choice, $4 choice to roll back to
run_module() {
  local id=$1 action=$2 undo=remove
  [[ $action == remove ]] && undo=install
  echo "@@start $id $action"
  run_strict module_action "$id" "$action" "${3:-}"
  if ((STRICT_RC == 0)); then
    echo "@@ok $id"
    return 0
  fi
  if ((STRICT_RC == REFUSED)); then
    echo "@@refused $id"
  else
    log "Rolling back $id"
    run_strict module_action "$id" "$undo" "${4:-}"
    if ((STRICT_RC != 0)); then
      warn "Rollback of $id failed too: check it by hand."
      echo "@@rollback-failed $id"
    fi
  fi
  echo "@@fail $id"
  MODULE_FAILED=$id
}

engine_prepare() {
  step_preflight
  step_packages
  step_upstream
  load_variant "$1"
  TAHOE_YES=1 step_assets
}

engine_apply() {
  local variant='' images=false arg id cur
  local -A want=() current=()
  # MacTahoe runs setterm under set -e: it fails without a TERM, or with xterm-ghostty once Ghostty's
  # snap (and its terminfo) is removed; the output goes to a log anyway
  export TERM=dumb
  while (($#)); do
    case $1 in
      --variant) variant=$2; shift 2 ;;
      --bg-light) export TAHOE_BG_LIGHT=$2; images=true; shift 2 ;;
      --bg-dark) export TAHOE_BG_DARK=$2; images=true; shift 2 ;;
      --logo) export TAHOE_LOGO=$2; images=true; shift 2 ;;
      *=*)
        arg=$1
        valid_module "${arg%%=*}" "${arg#*=}" || { log "Unknown module or value: $arg"; return 2; }
        want[${arg%%=*}]=${arg#*=}
        shift ;;
      *) log "Usage: tahoe-engine apply [--variant V] [--bg-light P] [--bg-dark P] [--logo P] module=on|off ..."; return 2 ;;
    esac
  done
  [[ ${want[theme]:-} == off || ${want[gtk4]:-} == off ]] && want[switch]=off

  local before
  before=$(current_variant)
  local refresh=$images
  [[ -n $variant && $variant != "$before" ]] && refresh=true

  local removes=() installs=()
  for id in "${MODULES[@]}"; do
    cur=$("mod_${id}_status")
    current[$id]=$cur
    if [[ $id == launcher ]]; then
      [[ -v want[launcher] && ${want[launcher]} != "$cur" ]] && installs+=(launcher)
      continue
    fi
    if [[ ${want[$id]:-} == off ]]; then
      [[ $cur == on ]] && removes+=("$id")
      continue
    fi
    if [[ ${want[$id]:-} == on && $cur != on ]] ||
      { $refresh && [[ $cur == on && " ${VARIANT_MODULES[*]} " == *" $id "* ]]; }; then
      installs+=("$id")
    fi
  done
  ((${#removes[@]} + ${#installs[@]})) || { log "Nothing to change."; return 0; }

  MODULE_FAILED=''
  if ((${#installs[@]})); then
    variant=${variant:-$before}
    [[ -n $variant ]] || { log "Choose a variant first."; return 2; }
    echo "@@start prepare install"
    run_strict engine_prepare "$variant"
    ((STRICT_RC == 0)) || { echo "@@fail prepare"; return 1; }
    echo "@@ok prepare"
  fi
  # prepare ran in a subshell: the modules (and their rollbacks) read the variant and images from here
  # shellcheck disable=SC1091
  [[ ! -f $RUNTIME/tahoe.conf ]] || source "$RUNTIME/tahoe.conf"

  local i
  for ((i = ${#removes[@]} - 1; i >= 0; i--)); do
    run_module "${removes[i]}" remove
    [[ -z $MODULE_FAILED ]] || return 1
  done
  for id in "${installs[@]}"; do
    run_module "$id" install "${want[$id]:-}" "${current[$id]}"
    [[ -z $MODULE_FAILED ]] || return 1
  done
}
