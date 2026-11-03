step_preflight() {
  [[ $(id -u) != 0 ]] || die "Run as your normal user, not root. sudo is asked when needed."
  if ! grep -qx 'ID=ubuntu' "$OS_RELEASE" || ! grep -qx 'VERSION_ID="24.04"' "$OS_RELEASE"; then
    die "This installer supports Ubuntu 24.04 only."
  fi

  if [[ ${XDG_SESSION_TYPE:-} == wayland ]]; then
    warn "Wayland session: the kit is tested on X11. Nautilus window restore and some extensions may misbehave."
    ask_yes_no "Continue anyway? (X11 recommended: pick 'Ubuntu on Xorg' at login)" n || die "Stopped."
  fi

  log "sudo is needed for apt, snap, the login screen and the boot splash."
  sudo -v
  (while kill -0 "$$" 2>/dev/null && sudo -n true; do sleep 60; done) >/dev/null 2>&1 3>&- &
}
