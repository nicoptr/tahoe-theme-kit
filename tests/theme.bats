load helpers

fake_script() {
  mkdir -p "$(dirname "$1")"
  printf '#!/usr/bin/env bash\necho "%s $*" >>"$CALLS"\n%s\n' "$(basename "$(dirname "$1")")/$(basename "$1")" "${2:-}" >"$1"
  chmod +x "$1"
}

setup_theme() {
  load_lib
  source "$REPO_DIR/variants/amethyst.conf"
  fake_script "$CACHE/MacTahoe-gtk-theme/install.sh" '
for m in Light Dark; do
  mkdir -p "$HOME/.themes/MacTahoe-$m-purple/gnome-shell" "$HOME/.themes/MacTahoe-$m-purple/gtk-4.0" "$HOME/.config/gtk-4.0"
  echo "#panel { color: red; }" >"$HOME/.themes/MacTahoe-$m-purple/gnome-shell/gnome-shell.css"
  echo "window { box-shadow: 0 1px RGB(0 0 0/15%); }" >"$HOME/.themes/MacTahoe-$m-purple/gtk-4.0/gtk.css"
  echo "window { box-shadow: 0 1px RGB(0 0 0/15%); }" >"$HOME/.config/gtk-4.0/gtk-$m.css"
done'
}

@test "theme: runs MacTahoe install.sh with the kit options" {
  setup_theme
  run step_theme
  [ "$status" -eq 0 ]
  grep -qx -- "MacTahoe-gtk-theme/install.sh -o normal -c dark -c light -t purple -l -HD --shell -p 45 -h smaller --round" "$CALLS"
}

@test "theme: shell overrides appended with the accent substituted" {
  setup_theme
  run step_theme
  css=$HOME/.themes/MacTahoe-Light-purple/gnome-shell/gnome-shell.css
  grep -q 'tahoe-light-shell overrides' "$css"
  grep -q '#7a3f84' "$css"
  ! grep -q '@ACCENT_HEX@' "$css"
  grep -q 'tahoe-dark-shell overrides' "$HOME/.themes/MacTahoe-Dark-purple/gnome-shell/gnome-shell.css"
}

@test "theme: RGB(r g b/a%) becomes rgba() in GTK4 css" {
  setup_theme
  run step_theme
  grep -q 'rgba(0, 0, 0, 0.15)' "$HOME/.config/gtk-4.0/gtk-Dark.css"
  grep -q 'rgba(0, 0, 0, 0.15)' "$HOME/.themes/MacTahoe-Light-purple/gtk-4.0/gtk.css"
  ! grep -q 'RGB(' "$HOME/.config/gtk-4.0/gtk-Light.css"
}

@test "theme: two runs leave one overrides block" {
  setup_theme
  fake_script "$CACHE/MacTahoe-gtk-theme/install.sh"
  mkdir -p "$HOME"/.themes/MacTahoe-{Light,Dark}-purple/gnome-shell
  touch "$HOME"/.themes/MacTahoe-{Light,Dark}-purple/gnome-shell/gnome-shell.css
  step_theme && step_theme
  [ "$(grep -c 'tahoe-dark-shell overrides' "$HOME/.themes/MacTahoe-Dark-purple/gnome-shell/gnome-shell.css")" -eq 1 ]
}

@test "icons: icon theme, cursors and cursor setting" {
  setup_theme
  fake_script "$CACHE/MacTahoe-icon-theme/install.sh"
  fake_script "$CACHE/MacTahoe-icon-theme/cursors/install.sh"
  run step_icons
  [ "$status" -eq 0 ]
  grep -qx -- "MacTahoe-icon-theme/install.sh -t purple -b" "$CALLS"
  grep -qx "cursors/install.sh " "$CALLS"
  grep -qx "gsettings set org.gnome.desktop.interface cursor-theme MacTahoe-cursors" "$CALLS"
}
