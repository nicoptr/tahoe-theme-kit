load helpers

setup_runtime() {
  RT=$BATS_TEST_TMPDIR/rt
  mkdir -p "$RT" "$HOME/.config/gtk-4.0"
  cp "$REPO_DIR/runtime/tahoe-mode.sh" "$RT/"
  cat "$REPO_DIR/variants/amethyst.conf" >"$RT/tahoe.conf"
  export STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.10+livecss1
}

@test "dark: gtk4 symlink and gtk theme switch to dark" {
  setup_runtime
  run "$RT/tahoe-mode.sh" dark
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/gtk-4.0/gtk.css")" = gtk-Dark.css ]
  grep -q "^gsettings set org.gnome.desktop.interface gtk-theme MacTahoe-Dark-purple$" "$CALLS"
}

@test "user-theme schemas dir missing: no --schemadir" {
  setup_runtime
  run "$RT/tahoe-mode.sh" light
  [ "$status" -eq 0 ]
  grep -q "user-theme name MacTahoe-Light-purple" "$CALLS"
  ! grep -q -- --schemadir "$CALLS"
}

@test "user-theme schemas dir present: --schemadir passed" {
  setup_runtime
  mkdir -p "$HOME/.local/share/gnome-shell/extensions/user-theme@gnome-shell-extensions.gcampax.github.com/schemas"
  run "$RT/tahoe-mode.sh" light
  grep -q -- "--schemadir" "$CALLS"
}

@test "bad argument: exit 1" {
  setup_runtime
  run "$RT/tahoe-mode.sh" blue
  [ "$status" -eq 1 ]
}

@test "gen-themes.py writes the themes from the conf given as argument" {
  run python3 -I "$REPO_DIR/ghostty/gen-themes.py" "$REPO_DIR/variants/amethyst.conf"
  [ "$status" -eq 0 ]
  grep -qx 'background = #1d1a24' "$HOME/.config/ghostty/themes/tahoe-dark"
  grep -qx 'palette = 15=#f5f1fa' "$HOME/.config/ghostty/themes/tahoe-dark"
}
