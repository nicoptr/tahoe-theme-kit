load helpers

EXT=.local/share/gnome-shell/extensions

setup_mod() {
  load_lib
  source "$REPO_DIR/lib/modules.sh"
  source "$REPO_DIR/lib/engine.sh"
  export STUB_OUT_GSETTINGS="['ubuntu-appindicators@ubuntu.com', 'dash-to-dock@micxgx.gmail.com']"
}

fake_script() {
  mkdir -p "$(dirname "$1")"
  printf '#!/usr/bin/env bash\n%s\n' "${2:-}" >"$1" && chmod +x "$1"
}

@test "restore_or_delete: puts the user's backup back" {
  setup_mod
  mkdir -p "$HOME/.config/gtk-3.0"
  echo kit >"$HOME/.config/gtk-3.0/gtk.css"
  echo mine >"$HOME/.config/gtk-3.0/gtk.css.bak-tahoe"
  restore_or_delete "$HOME/.config/gtk-3.0/gtk.css"
  [ "$(cat "$HOME/.config/gtk-3.0/gtk.css")" = mine ]
  [ ! -e "$HOME/.config/gtk-3.0/gtk.css.bak-tahoe" ]
}

@test "restore_or_delete: no backup, the kit's file goes" {
  setup_mod
  mkdir -p "$HOME/.config/gtk-3.0"
  echo kit >"$HOME/.config/gtk-3.0/gtk.css"
  restore_or_delete "$HOME/.config/gtk-3.0/gtk.css"
  [ ! -e "$HOME/.config/gtk-3.0/gtk.css" ]
}

@test "extension modules: status follows the extension folder (works without tahoe.conf)" {
  setup_mod
  [ "$(mod_dock_status)" = off ]
  mkdir -p "$HOME/$EXT/dash-to-dock@micxgx.gmail.com"
  [ "$(mod_dock_status)" = on ]
}

@test "extension modules: remove disables, uninstalls and resets the settings" {
  setup_mod
  run mod_dock_remove
  [ "$status" -eq 0 ]
  grep -qx "gsettings set org.gnome.shell enabled-extensions \['ubuntu-appindicators@ubuntu.com'\]" "$CALLS"
  grep -qx "gnome-extensions uninstall dash-to-dock@micxgx.gmail.com" "$CALLS"
  grep -qx "dconf reset -f /org/gnome/shell/extensions/dash-to-dock/" "$CALLS"
}

@test "extension modules: install downloads the pinned zip, enables, loads settings" {
  setup_mod
  run mod_corners_install
  [ "$status" -eq 0 ]
  grep -q "^curl .*rounded-window-corners@fxgn.shell-extension.zip?version_tag=65276" "$CALLS"
  grep -q "^gsettings set org.gnome.shell enabled-extensions .*'rounded-window-corners@fxgn'" "$CALLS"
  grep -qx "dconf load /org/gnome/shell/extensions/rounded-window-corners-reborn/" "$CALLS"
}

@test "wobbly install applies the shadow patch" {
  setup_mod
  run mod_wobbly_install
  grep -q "^patch .*compiz-windows-effect-rwc-shadow.patch" "$CALLS"
}

@test "theme remove: Ubuntu's themes come back before MacTahoe is deleted" {
  setup_mod
  local gtk=$CACHE/MacTahoe-gtk-theme icons=$CACHE/MacTahoe-icon-theme
  fake_script "$gtk/install.sh" 'echo "mactahoe-gtk $*" >>"$CALLS"'
  fake_script "$icons/install.sh" 'echo "mactahoe-icons $*" >>"$CALLS"'
  mkdir -p "$HOME/.local/share/icons/MacTahoe-cursors"
  run mod_theme_remove
  [ "$status" -eq 0 ]
  local first_reset gtk_remove
  first_reset=$(grep -n '^gsettings reset org.gnome.desktop.interface gtk-theme' "$CALLS" | cut -d: -f1)
  gtk_remove=$(grep -n '^mactahoe-gtk -r' "$CALLS" | cut -d: -f1)
  [ -n "$first_reset" ] && [ -n "$gtk_remove" ] && [ "$first_reset" -lt "$gtk_remove" ]
  grep -q '^gsettings reset org.gnome.desktop.interface icon-theme' "$CALLS"
  grep -q '^gsettings reset org.gnome.desktop.interface cursor-theme' "$CALLS"
  grep -q 'reset org.gnome.shell.extensions.user-theme name' "$CALLS"
  grep -qx 'mactahoe-icons -r' "$CALLS"
  [ ! -d "$HOME/.local/share/icons/MacTahoe-cursors" ]
}

@test "theme status: on when a MacTahoe shell theme is installed" {
  setup_mod
  [ "$(mod_theme_status)" = off ]
  mkdir -p "$HOME/.themes/MacTahoe-Dark-purple/gnome-shell"
  [ "$(mod_theme_status)" = on ]
}

@test "wallpaper: status from picture-uri, remove resets it" {
  setup_mod
  STUB_OUT_GSETTINGS="'file://$RUNTIME/backgrounds/dark-x.png'" run mod_wallpaper_status
  [ "$output" = on ]
  run mod_wallpaper_remove
  grep -qx 'gsettings reset org.gnome.desktop.background picture-uri' "$CALLS"
  grep -qx 'gsettings reset org.gnome.desktop.background picture-uri-dark' "$CALLS"
}

@test "launcher: status names the installed one" {
  setup_mod
  [ "$(mod_launcher_status)" = none ]
  mkdir -p "$HOME/$EXT/search-light@icedman.github.com"
  [ "$(mod_launcher_status)" = searchlight ]
}

@test "launcher ulauncher: Search Light goes, Super+Space runs ulauncher-toggle" {
  setup_mod
  mkdir -p "$HOME/$EXT/search-light@icedman.github.com"
  run mod_launcher_set ulauncher
  [ "$status" -eq 0 ]
  grep -qx "gnome-extensions uninstall search-light@icedman.github.com" "$CALLS"
  grep -q "^sudo apt-get install -y .*ulauncher_5.16.2_all.deb" "$CALLS"
  grep -qx "dconf write $LAUNCHER_KEYBINDING/command 'ulauncher-toggle'" "$CALLS"
  grep -qx "dconf write $LAUNCHER_KEYBINDING/binding '<Super>space'" "$CALLS"
  [ "$(jq -r '."hotkey-show-app"' "$HOME/.config/ulauncher/settings.json")" = "" ]
}

@test "launcher none: both go and the layout switch gets Super+Space back" {
  setup_mod
  STUB_OUT_DPKG_QUERY='install ok installed' run mod_launcher_set none
  [ "$status" -eq 0 ]
  grep -qx 'sudo apt-get remove -y ulauncher' "$CALLS"
  grep -qx 'gsettings reset org.gnome.desktop.wm.keybindings switch-input-source' "$CALLS"
  grep -qx "dconf reset -f $LAUNCHER_KEYBINDING/" "$CALLS"
}

@test "switch remove: Switchcraft goes with its commands" {
  setup_mod
  mkdir -p "$HOME/.config/switchcraft"
  echo '{}' >"$HOME/.config/switchcraft/commands.json"
  run mod_switch_remove
  grep -qx 'sudo apt-get remove -y switchcraft' "$CALLS"
  [ ! -e "$HOME/.config/switchcraft/commands.json" ]
}

@test "ghostty remove: GNOME Terminal comes back as the default" {
  setup_mod
  cp /etc/skel/.bashrc "$HOME/"
  sed -i 's/xterm-color|\*-256color) color_prompt=yes;;/xterm-color|*-256color|xterm-ghostty) color_prompt=yes;;/' "$HOME/.bashrc"
  STUB_OUT_GSETTINGS="['org.gnome.Nautilus.desktop', 'ghostty_ghostty.desktop']" run mod_ghostty_remove
  [ "$status" -eq 0 ]
  grep -qx "gsettings set org.gnome.shell favorite-apps \['org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop'\]" "$CALLS"
  grep -qx 'gsettings reset org.gnome.desktop.default-applications.terminal exec' "$CALLS"
  grep -qx 'sudo apt-get install -y nautilus-extension-gnome-terminal' "$CALLS"
  grep -qx 'sudo snap remove ghostty' "$CALLS"
  refute grep -q xterm-ghostty "$HOME/.bashrc"
}

@test "nvidia: unavailable without an NVIDIA card" {
  setup_mod
  STUB_OUT_LSPCI='00:02.0 VGA compatible controller: Intel' run mod_nvidia_status
  [ "$output" = unavailable ]
}

@test "status through tahoe-engine works on a bare system" {
  run "$REPO_DIR/tahoe-engine" status
  [ "$status" -eq 0 ]
  python3 -I -c 'import json, sys; m = json.loads(sys.argv[1])["modules"]; assert m["theme"] == "off" and m["launcher"] == "none", m' "$output"
}

@test "launcher searchlight: patched, Super+Space taken from the layout switch" {
  setup_mod
  run mod_launcher_set searchlight
  [ "$status" -eq 0 ]
  grep -q "^patch -d $HOME/$EXT -p0 -i $REPO_DIR/patches/search-light-blur.patch" "$CALLS"
  grep -qx "gsettings set org.gnome.desktop.wm.keybindings switch-input-source \\['XF86Keyboard'\\]" "$CALLS"
  grep -qx "shortcut-search=\\['<Super>space'\\]" "$REPO_DIR/dconf/search-light.dconf"
}
