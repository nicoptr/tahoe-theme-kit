load helpers

setup_settings() {
  load_lib
  source "$REPO_DIR/variants/amethyst.conf"
  mkdir -p "$RUNTIME"
  printf 'BG_LIGHT=%q\nBG_DARK=%q\n' "$RUNTIME/backgrounds/light-a b.png" "$RUNTIME/backgrounds/dark-n.jpg" >"$RUNTIME/tahoe.conf"
}

@test "settings: wallpapers set as file URIs, spaces encoded" {
  setup_settings
  run step_settings
  [ "$status" -eq 0 ]
  grep -qx "gsettings set org.gnome.desktop.background picture-uri file://$RUNTIME/backgrounds/light-a%20b.png" "$CALLS"
  grep -qx "gsettings set org.gnome.desktop.background picture-uri-dark file://$RUNTIME/backgrounds/dark-n.jpg" "$CALLS"
}

@test "settings: terminal follows the system and tmpfiles service enabled" {
  setup_settings
  run step_settings
  grep -qx "dconf write /org/gnome/terminal/legacy/theme-variant 'system'" "$CALLS"
  grep -qx "systemctl --user enable systemd-tmpfiles-setup.service" "$CALLS"
}

@test "settings: switchcraft commands point to the runtime copy" {
  setup_settings
  run step_settings
  grep -q "\"$HOME/.local/share/tahoe-theme-kit/tahoe-mode.sh dark\"" "$HOME/.config/switchcraft/commands.json"
  grep -q "/MacTahoe-purple/apps/symbolic/" "$HOME/.config/user-tmpfiles.d/rustdesk-tray-icon.conf"
}

@test "settings: an existing different file is backed up once" {
  setup_settings
  mkdir -p "$HOME/.config/gtk-3.0" && echo mine >"$HOME/.config/gtk-3.0/gtk.css"
  run step_settings
  run step_settings
  [ "$(cat "$HOME/.config/gtk-3.0/gtk.css.bak-tahoe")" = mine ]
  grep -q scrollbar "$HOME/.config/gtk-3.0/gtk.css"
}

@test "switchcraft: downloads the pinned deb and installs it" {
  load_lib
  run step_switchcraft
  [ "$status" -eq 0 ]
  grep -q "^curl .*https://github.com/kem-a/switchcraft/releases/download/v1.2.1/switchcraft_1.2.1_amd64.deb" "$CALLS"
  grep -qx "sudo apt-get install -y $CACHE/downloads/switchcraft_1.2.1_amd64.deb" "$CALLS"
}

@test "switchcraft: already installed → nothing downloaded" {
  load_lib
  STUB_OUT_DPKG_QUERY='install ok installed' run step_switchcraft
  [ "$status" -eq 0 ]
  refute grep -q '^curl' "$CALLS"
}

@test "switchcraft: checksum mismatch → not installed" {
  load_lib
  STUB_RC_SHA256SUM=1 run strict step_switchcraft
  [ "$status" -ne 0 ]
  refute grep -q '^sudo apt-get install' "$CALLS"
}

@test "ulauncher: downloads the pinned deb and installs it" {
  load_lib
  run step_ulauncher
  [ "$status" -eq 0 ]
  grep -qx "sudo apt-get install -y $CACHE/downloads/ulauncher_5.16.2_all.deb" "$CALLS"
}

@test "settings: ulauncher starts at login with the Ctrl+Super hotkey" {
  setup_settings
  run step_settings
  grep -q '^Exec=.*ulauncher --hide-window$' "$HOME/.config/autostart/ulauncher.desktop"
  [ "$(jq -r '."hotkey-show-app"' "$HOME/.config/ulauncher/settings.json")" = '<Primary>Super_L' ]
}

@test "settings: a symlinked config file stays a symlink and keeps its mode" {
  setup_settings
  mkdir -p "$HOME/dotfiles" "$HOME/.config/gtk-3.0"
  echo mine >"$HOME/dotfiles/gtk.css" && chmod 644 "$HOME/dotfiles/gtk.css"
  ln -s "$HOME/dotfiles/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
  run step_settings
  [ -L "$HOME/.config/gtk-3.0/gtk.css" ]
  grep -q scrollbar "$HOME/dotfiles/gtk.css"
  [ "$(stat -c %a "$HOME/dotfiles/gtk.css")" = 644 ]
}
