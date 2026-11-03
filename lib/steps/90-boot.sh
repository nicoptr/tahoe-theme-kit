YARU_GRESOURCE=/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource
PLYMOUTH_THEMES=/usr/share/plymouth/themes

step_gdm() {
  ask_yes_no "Login screen theme (GDM, dark variant with your dark wallpaper)?" y || return 0
  source "$RUNTIME/tahoe.conf"
  # no -c: tweaks.sh reads colors[1], which is empty when a single color is passed
  (cd "$CACHE/MacTahoe-gtk-theme" && sudo ./tweaks.sh -g -b "$BG_DARK" -p 45 -h smaller -t "$ACCENT")
  # Ubuntu's GDM reads this alternative, which may still point to an old custom theme
  sudo update-alternatives --set gdm-theme.gresource "$YARU_GRESOURCE"
}

plymouth_theme_file() {
  sed "s/@ACCENT_0X@/0x${ACCENT_HEX#\#}/" "$REPO_DIR/plymouth/tahoe-logo.plymouth" >"$1"
}

step_plymouth() {
  ask_yes_no "Boot splash with your logo (Plymouth)?" y || return 0
  source "$RUNTIME/tahoe.conf"
  local dest=$PLYMOUTH_THEMES/tahoe-logo build
  build=$(mktemp -d)
  convert "$PLYMOUTH_LOGO" -trim +repage "$build/watermark.png"
  plymouth_theme_file "$build/tahoe-logo.plymouth"

  sudo mkdir -p "$dest"
  sudo find "$PLYMOUTH_THEMES/spinner" -name '*.png' ! -name watermark.png ! -name bgrt-fallback.png -exec cp {} "$dest" \;
  sudo cp "$build/tahoe-logo.plymouth" "$build/watermark.png" "$dest"
  rm -r "$build"

  sudo update-alternatives --install "$PLYMOUTH_THEMES/default.plymouth" default.plymouth "$dest/tahoe-logo.plymouth" 100
  sudo update-alternatives --set default.plymouth "$dest/tahoe-logo.plymouth"
  sudo update-initramfs -u
}

step_nvidia() {
  lspci | grep -qi nvidia || return 0
  if ! nvidia-smi >/dev/null 2>&1; then
    warn "NVIDIA GPU found but nvidia-smi fails: the desktop is probably running on software rendering."
    warn "Fix the driver first (Additional Drivers, or the precompiled linux-modules-nvidia-<ver>-open-generic)."
  fi
  ask_yes_no "Use GSK_RENDERER=gl? Fixes near-white button borders in GTK4 apps on some NVIDIA cards" n || return 0
  mkdir -p "$HOME/.config/environment.d"
  cp "$REPO_DIR/optional/60-gsk-renderer.conf" "$HOME/.config/environment.d/"
}

step_finish() {
  "$RUNTIME/tahoe-mode.sh" dark
  log ""
  log "Done. Left to do by hand:"
  log "  1. Log out and back in (X11: pick 'Ubuntu on Xorg'), so the extensions start."
  log "  2. Open Switchcraft → Preferences → turn on Monitoring. This makes the Dark Style button run tahoe-mode.sh."
  log "  3. Set your apps to follow the system theme (README → Apps)."
  log "  4. Press Dark Style a few times and check: theme, icons, wallpaper, Ghostty, Nautilus, panel, quick settings."
  log "  5. Reboot once to see the login screen and the boot splash."
}
