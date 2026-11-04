step_preflight() {
  [[ $(id -u) != 0 ]] || die "Run as your normal user, not root. sudo is asked when needed."
  if ! grep -qx 'ID=ubuntu' "$OS_RELEASE" || ! grep -qx 'VERSION_ID="24.04"' "$OS_RELEASE"; then
    die "This installer supports Ubuntu 24.04 only."
  fi

  [[ ${XDG_SESSION_TYPE:-} != wayland ]] ||
    log "Wayland session: everything works; only the wobbly windows shadow can stay behind as a square."

  log "sudo is needed for apt, snap, the login screen and the boot splash."
  sudo -v
  (while kill -0 "$$" 2>/dev/null && sudo -n true; do sleep 60; done) >/dev/null 2>&1 3>&- &
}
