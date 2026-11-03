SNAP_DESKTOP=${SNAP_DESKTOP:-/var/lib/snapd/desktop/applications/ghostty_ghostty.desktop}

use_ghostty_as_terminal() {
  local apps=$HOME/.local/share/applications favorites
  # the snap's icon is a fixed PNG path that bypasses the icon theme
  mkdir -p "$apps"
  sed 's|^Icon=.*|Icon=org.gnome.Terminal|' "$SNAP_DESKTOP" >"$apps/ghostty_ghostty.desktop"

  favorites=$(gsettings get org.gnome.shell favorite-apps)
  gsettings set org.gnome.shell favorite-apps "${favorites//\'org.gnome.Terminal.desktop\'/\'ghostty_ghostty.desktop\'}"
  gsettings set org.gnome.desktop.default-applications.terminal exec ghostty
  gsettings set org.gnome.desktop.default-applications.terminal exec-arg -e
}

step_ghostty() {
  snap list ghostty >/dev/null 2>&1 || sudo snap install ghostty --classic

  local dir=$HOME/.config/ghostty
  mkdir -p "$dir"
  install_file "$REPO_DIR/ghostty/config" "$dir/config"
  install_file "$REPO_DIR/ghostty/tahoe.css" "$dir/tahoe.css"
  python3 -I "$RUNTIME/gen-themes.py" "$RUNTIME/tahoe.conf"
  ghostty +validate-config

  use_ghostty_as_terminal

  # Ubuntu's .bashrc enables the colored prompt only for xterm-color and *-256color
  [[ ! -f $HOME/.bashrc ]] || grep -q 'xterm-ghostty) color_prompt=yes' "$HOME/.bashrc" ||
    sed -i 's/^\(\s*\)xterm-color|\*-256color) color_prompt=yes;;/\1xterm-color|*-256color|xterm-ghostty) color_prompt=yes;;/' "$HOME/.bashrc"

  local claude=$HOME/.claude/settings.json tmp
  [[ -f $claude ]] || return 0
  tmp=$(mktemp)
  jq '.theme = "auto"' "$claude" >"$tmp" && mv "$tmp" "$claude"
}
