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
  VARIANT_CONF=$conf
  source "$conf"
}

ask_image() {
  local prompt=$1 default=$2 path interactive=true
  [[ ${TAHOE_YES:-} == 1 ]] && interactive=false
  while true; do
    path=
    if $interactive; then
      printf '%s\n  Enter keeps %s\n  path: ' "$prompt" "$default" >&2
      read -r path || interactive=false
    fi
    path=${path:-$default}
    path=${path/#\~/$HOME}
    if identify "$path" >/dev/null 2>&1; then
      realpath "$path"
      return 0
    fi
    $interactive || die "Not an image: $path"
    log "Not an image: $path"
  done
}

download() {
  local url=$1 dest=$2 sha256=$3
  if ! curl --proto '=https' --proto-redir '=https' -fsSL -o "$dest" "$url"; then
    warn "Download failed: $url"
    return 1
  fi
  sha256sum --check --status <<<"$sha256  $dest" && return 0
  rm -f "$dest"
  warn "Checksum mismatch: $url"
  return 1
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
