load helpers

setup_ghostty() {
  load_lib
  mkdir -p "$RUNTIME"
  cp "$REPO_DIR/variants/amethyst.conf" "$RUNTIME/tahoe.conf"
  cp "$REPO_DIR/ghostty/gen-themes.py" "$RUNTIME/"
  export SNAP_DESKTOP=$BATS_TEST_TMPDIR/ghostty_ghostty.desktop
  printf '[Desktop Entry]\nName=Ghostty\nIcon=/snap/ghostty/x/icon.png\n' >"$SNAP_DESKTOP"
  cp /etc/skel/.bashrc "$HOME/.bashrc"
  export STUB_OUT_GSETTINGS="['org.gnome.Terminal.desktop', 'firefox_firefox.desktop']"
}

@test "ghostty: snap installed when missing, skipped when present" {
  setup_ghostty
  STUB_RC_SNAP=1 run step_ghostty
  grep -qx "sudo snap install ghostty --classic" "$CALLS"
  : >"$CALLS"
  run step_ghostty
  ! grep -q "^sudo snap install" "$CALLS"
}

@test "ghostty: config, css with absolute import, generated themes" {
  setup_ghostty
  run step_ghostty
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/ghostty/config" ]
  grep -q "file://$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/ghostty/tahoe.css"
  ! grep -q '@HOME@' "$HOME/.config/ghostty/tahoe.css"
  grep -qx 'background = #96e4de' "$HOME/.config/ghostty/themes/tahoe-light"
  grep -qx "ghostty +validate-config" "$CALLS"
}

@test "ghostty: MacTahoe terminal icon in the local desktop file" {
  setup_ghostty
  run step_ghostty
  grep -qx 'Icon=org.gnome.Terminal' "$HOME/.local/share/applications/ghostty_ghostty.desktop"
}

@test "ghostty: replaces GNOME Terminal in the dock, keeps the order, default terminal" {
  setup_ghostty
  run step_ghostty
  grep -qx "gsettings set org.gnome.shell favorite-apps \['ghostty_ghostty.desktop', 'firefox_firefox.desktop'\]" "$CALLS"
  grep -qx "gsettings set org.gnome.desktop.default-applications.terminal exec ghostty" "$CALLS"
}

@test "ghostty: colored prompt for xterm-ghostty added once" {
  setup_ghostty
  step_ghostty && step_ghostty
  [ "$(grep -c 'xterm-ghostty' "$HOME/.bashrc")" -eq 1 ]
}

@test "ghostty: claude settings get theme auto only when the file exists" {
  setup_ghostty
  run step_ghostty
  [ ! -e "$HOME/.claude/settings.json" ]
  mkdir -p "$HOME/.claude" && echo '{"model": "x"}' >"$HOME/.claude/settings.json"
  run step_ghostty
  [ "$(jq -r .theme "$HOME/.claude/settings.json")" = auto ]
  [ "$(jq -r .model "$HOME/.claude/settings.json")" = x ]
}

@test "ghostty: no .bashrc is fine" {
  setup_ghostty
  rm "$HOME/.bashrc"
  run strict step_ghostty
  [ "$status" -eq 0 ]
}

@test "ghostty: added to the dock once when GNOME Terminal is not there" {
  setup_ghostty
  STUB_OUT_GSETTINGS="['firefox_firefox.desktop']" run step_ghostty
  grep -qx "gsettings set org.gnome.shell favorite-apps \['firefox_firefox.desktop', 'ghostty_ghostty.desktop'\]" "$CALLS"
  : >"$CALLS"
  STUB_OUT_GSETTINGS="['firefox_firefox.desktop', 'ghostty_ghostty.desktop']" run step_ghostty
  grep -qx "gsettings set org.gnome.shell favorite-apps \['firefox_firefox.desktop', 'ghostty_ghostty.desktop'\]" "$CALLS"
}

@test "ghostty: Nautilus opens folders in Ghostty instead of GNOME Terminal" {
  setup_ghostty
  run step_ghostty
  [ "$status" -eq 0 ]
  grep -qx "sudo apt-get remove -y nautilus-extension-gnome-terminal" "$CALLS"
  grep -q '"ghostty"' "$HOME/.local/share/nautilus-python/extensions/tahoe-ghostty.py"
}
