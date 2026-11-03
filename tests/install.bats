load helpers

fake_script() {
  mkdir -p "$(dirname "$1")"
  printf '#!/usr/bin/env bash\n%s\n' "${2:-}" >"$1" && chmod +x "$1"
}

@test "install.sh amethyst runs every step with default answers" {
  local gtk=$HOME/.cache/tahoe-theme-kit/MacTahoe-gtk-theme icons=$HOME/.cache/tahoe-theme-kit/MacTahoe-icon-theme
  mkdir -p "$gtk/.git" "$icons/.git" "$gtk/wallpaper"
  convert -size 4x4 xc:red "$gtk/wallpaper/MacTahoe-day.jpeg"
  convert -size 4x4 xc:navy "$gtk/wallpaper/MacTahoe-night.jpeg"
  convert -size 4x4 xc:white "$BATS_TEST_TMPDIR/ubuntu-logo.png"
  fake_script "$gtk/install.sh" 'mkdir -p "$HOME/.config/gtk-4.0"; for m in Light Dark; do mkdir -p "$HOME/.themes/MacTahoe-$m-purple/gnome-shell"; touch "$HOME/.themes/MacTahoe-$m-purple/gnome-shell/gnome-shell.css"; done'
  fake_script "$icons/install.sh"
  fake_script "$icons/cursors/install.sh"
  printf '[Desktop Entry]\nIcon=x\n' >"$BATS_TEST_TMPDIR/ghostty.desktop"
  cp /etc/skel/.bashrc "$HOME/"

  TAHOE_YES=1 PLYMOUTH_DEFAULT=$BATS_TEST_TMPDIR/ubuntu-logo.png SNAP_DESKTOP=$BATS_TEST_TMPDIR/ghostty.desktop \
    STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.10+livecss1 STUB_OUT_GSETTINGS='@as []' \
    run "$REPO_DIR/install.sh" amethyst
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[15/15] finish"* ]]
  [[ "$output" == *Monitoring* ]]
  [ -L "$HOME/.config/gtk-4.0/gtk.css" ]
}
