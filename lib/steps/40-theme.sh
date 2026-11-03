append_shell_css() {
  local mode=$1 css="$HOME/.themes/MacTahoe-$1-$ACCENT/gnome-shell/gnome-shell.css"
  local source=$REPO_DIR/shell/tahoe-${mode,,}-shell.css
  sed -i "/tahoe-${mode,,}-shell overrides/,\$d" "$css"
  sed "s/@ACCENT_HEX@/$ACCENT_HEX/g" "$source" >>"$css"
}

step_theme() {
  (cd "$CACHE/MacTahoe-gtk-theme" && ./install.sh -o normal -c dark -c light -t "$ACCENT" -l -HD --shell -p 45 -h smaller --round)
  append_shell_css Light
  append_shell_css Dark

  # GTK 4.14 can't parse RGB(r g b/a%): the window shadows get dropped
  local css
  for css in "$HOME"/.config/gtk-4.0/gtk-{Light,Dark}.css "$HOME"/.themes/MacTahoe-*-"$ACCENT"/gtk-4.0/gtk*.css; do
    [[ -f $css ]] || continue
    perl -pi -e 's{RGB\((\d+) (\d+) (\d+)/(\d+)%\)}{sprintf("rgba(%d, %d, %d, %.2f)",$1,$2,$3,$4/100)}ge' "$css"
  done
}

step_icons() {
  (cd "$CACHE/MacTahoe-icon-theme" && ./install.sh -t "$ACCENT" -b)
  (cd "$CACHE/MacTahoe-icon-theme/cursors" && ./install.sh)
  gsettings set org.gnome.desktop.interface cursor-theme MacTahoe-cursors
}
