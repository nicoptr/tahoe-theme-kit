RUNTIME=$HOME/.local/share/tahoe-theme-kit
CACHE=$HOME/.cache/tahoe-theme-kit
OS_RELEASE=${OS_RELEASE:-/etc/os-release}

log() { printf '%s\n' "$*" >&2; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

ask_yes_no() {
  local prompt=$1 default=$2 hint answer
  [[ $default == y ]] && hint='[Y/n]' || hint='[y/N]'
  [[ ${TAHOE_YES:-} == 1 ]] && answer=$default
  while true; do
    if [[ -z ${answer:-} ]]; then
      printf '%s %s ' "$prompt" "$hint" >&2
      read -r answer || answer=
    fi
    case ${answer:-$default} in
      [Yy] | [Yy][Ee][Ss]) return 0 ;;
      [Nn] | [Nn][Oo]) return 1 ;;
    esac
    answer=
  done
}

variant_names() {
  local f names=()
  for f in "$REPO_DIR"/variants/*.conf; do
    [[ -e $f ]] && names+=("$(basename "$f" .conf)")
  done
  echo "${names[*]}"
}

load_variant() {
  local conf=$REPO_DIR/variants/${1:-}.conf
  if [[ -z ${1:-} || ! -f $conf ]]; then
    log "Usage: $(basename "$0") <variant>"
    log "Variants: $(variant_names)"
    exit 2
  fi
  source "$conf"
}

render() {
  local text
  text=$(<"$1")
  text=${text//@ACCENT_HEX@/"${ACCENT_HEX:-}"}
  text=${text//@ACCENT@/"${ACCENT:-}"}
  text=${text//@ICON_THEME@/"${ICON_THEME:-}"}
  text=${text//@HOME@/"$HOME"}
  text=${text//@RUNTIME@/"${RUNTIME:-}"}
  printf '%s\n' "$text" >"$2"
}
