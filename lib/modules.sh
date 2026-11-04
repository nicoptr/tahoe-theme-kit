# Each module has mod_<id>_install, mod_<id>_remove and mod_<id>_status (on, off or unavailable).
# The launcher is a choice: mod_launcher_status prints it and mod_launcher_set <choice> applies it.

# apply order: installs run in this order, removes in reverse
MODULES=(theme wallpaper dock blur corners hidetopbar coverflow wobbly launcher switch gtk4 ghostty gdm plymouth nvidia)
LAUNCHER_CHOICES=(searchlight ulauncher none)
# modules that read the variant or the images, reinstalled when those change
VARIANT_MODULES=(theme wallpaper ghostty gdm plymouth)
# a remove that stops before changing anything returns this, so the engine doesn't roll it back
REFUSED=3

EXT_DIR=$HOME/.local/share/gnome-shell/extensions
SEARCH_LIGHT_UUID=search-light@icedman.github.com
USER_THEME_UUID=user-theme@gnome-shell-extensions.gcampax.github.com
LAUNCHER_KEYBINDING=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/tahoe-launcher
THEME_FILES=(.config/gtk-3.0/gtk.css .config/user-tmpfiles.d/rustdesk-tray-icon.conf)
SWITCH_FILES=(.config/switchcraft/commands.json)
ULAUNCHER_FILES=(.config/ulauncher/settings.json .config/autostart/ulauncher.desktop)
KEYBINDINGS=org.gnome.desktop.wm.keybindings

on_off() { if "$@"; then echo on; else echo off; fi; }
pkg_installed() { [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == 'install ok installed' ]]; }

restore_or_delete() {
  # install_file wrote through a symlinked dotfile: put the content back the same way
  if [[ -e $1.bak-tahoe && -L $1 ]]; then
    cat "$1.bak-tahoe" >"$1"
    rm -f "$1.bak-tahoe"
  elif [[ -e $1.bak-tahoe ]]; then
    mv -f "$1.bak-tahoe" "$1"
  else
    rm -f "$1"
  fi
}

install_kit_files() {
  local rel
  for rel; do install_file "$REPO_DIR/files/$rel" "$HOME/$rel"; done
}

remove_kit_files() {
  local rel
  for rel; do restore_or_delete "$HOME/$rel"; done
}

apply_mode() {
  local mode=light
  [[ "$(gsettings get org.gnome.desktop.interface color-scheme)" == *dark* ]] && mode=dark
  "$RUNTIME/tahoe-mode.sh" "$mode"
}

extension_installed() { [[ -d $EXT_DIR/$1 ]]; }

# $1 uuid, then the dconf paths under /org/gnome/shell/extensions/ it owns
add_extension() {
  local uuid=$1 tag sha256
  shift
  read -r _ tag sha256 <<<"$(extension_entry "$uuid")"
  mkdir -p "$CACHE/downloads"
  install_extension "$uuid" "$tag" "$sha256"
  enable_extensions "$uuid"
  load_extension_settings "$@"
}

drop_extension() {
  local uuid=$1 p
  shift
  edit_list org.gnome.shell enabled-extensions remove "$uuid"
  gnome-extensions uninstall "$uuid" || true
  for p; do dconf reset -f "/org/gnome/shell/extensions/$p/"; done
}

theme_installed() { compgen -G "$HOME/.themes/MacTahoe-Dark-*/gnome-shell" >/dev/null; }
mod_theme_status() { on_off theme_installed; }
mod_theme_install() {
  step_theme
  step_icons
  add_extension "$USER_THEME_UUID" appindicator
  install_kit_files "${THEME_FILES[@]}"
  systemctl --user enable systemd-tmpfiles-setup.service
  apply_mode
}
mod_theme_remove() {
  local interface=org.gnome.desktop.interface schemadir=()
  # Ubuntu's themes first, so GNOME never points at a deleted one
  gsettings reset "$interface" gtk-theme
  gsettings reset "$interface" icon-theme
  gsettings reset "$interface" cursor-theme
  [[ -d $EXT_DIR/$USER_THEME_UUID/schemas ]] && schemadir=(--schemadir "$EXT_DIR/$USER_THEME_UUID/schemas")
  gsettings "${schemadir[@]}" reset org.gnome.shell.extensions.user-theme name || true
  drop_extension "$USER_THEME_UUID" appindicator
  remove_kit_files "${THEME_FILES[@]}"
  if [[ -x $CACHE/MacTahoe-gtk-theme/install.sh ]]; then
    (cd "$CACHE/MacTahoe-gtk-theme" && ./install.sh -r)
  else
    rm -rf "$HOME"/.themes/MacTahoe-{Light,Dark}-*
  fi
  if [[ -x $CACHE/MacTahoe-icon-theme/install.sh ]]; then
    (cd "$CACHE/MacTahoe-icon-theme" && ./install.sh -r)
  else
    rm -rf "$HOME"/.local/share/icons/MacTahoe-*
  fi
  rm -rf "$HOME/.local/share/icons/MacTahoe-cursors"
}

mod_wallpaper_status() { on_off grep -q "$RUNTIME/backgrounds/" <<<"$(gsettings get org.gnome.desktop.background picture-uri-dark)"; }
mod_wallpaper_install() {
  source "$RUNTIME/tahoe.conf"
  gsettings set org.gnome.desktop.background picture-uri "$(file_uri "$BG_LIGHT")"
  gsettings set org.gnome.desktop.background picture-uri-dark "$(file_uri "$BG_DARK")"
  dconf write /org/gnome/terminal/legacy/theme-variant "'system'"
}
mod_wallpaper_remove() {
  gsettings reset org.gnome.desktop.background picture-uri
  gsettings reset org.gnome.desktop.background picture-uri-dark
  dconf reset /org/gnome/terminal/legacy/theme-variant
}

mod_dock_status() { on_off extension_installed dash-to-dock@micxgx.gmail.com; }
mod_dock_install() { add_extension dash-to-dock@micxgx.gmail.com dash-to-dock; }
mod_dock_remove() { drop_extension dash-to-dock@micxgx.gmail.com dash-to-dock; }

mod_blur_status() { on_off extension_installed blur-my-shell@aunetx; }
mod_blur_install() { add_extension blur-my-shell@aunetx blur-my-shell; }
mod_blur_remove() { drop_extension blur-my-shell@aunetx blur-my-shell; }

mod_corners_status() { on_off extension_installed rounded-window-corners@fxgn; }
mod_corners_install() { add_extension rounded-window-corners@fxgn rounded-window-corners-reborn; }
mod_corners_remove() { drop_extension rounded-window-corners@fxgn rounded-window-corners-reborn; }

mod_hidetopbar_status() { on_off extension_installed hidetopbar@mathieu.bidon.ca; }
mod_hidetopbar_install() { add_extension hidetopbar@mathieu.bidon.ca hidetopbar; }
mod_hidetopbar_remove() { drop_extension hidetopbar@mathieu.bidon.ca hidetopbar; }

mod_coverflow_status() { on_off extension_installed CoverflowAltTab@palatis.blogspot.com; }
mod_coverflow_install() { add_extension CoverflowAltTab@palatis.blogspot.com; }
mod_coverflow_remove() { drop_extension CoverflowAltTab@palatis.blogspot.com; }

mod_wobbly_status() { on_off extension_installed compiz-windows-effect@hermes83.github.com; }
mod_wobbly_install() {
  add_extension compiz-windows-effect@hermes83.github.com
  patch -d "$EXT_DIR" -p0 -i "$REPO_DIR/patches/compiz-windows-effect-rwc-shadow.patch"
}
mod_wobbly_remove() { drop_extension compiz-windows-effect@hermes83.github.com; }

free_super_space() {
  gsettings set "$KEYBINDINGS" switch-input-source "['XF86Keyboard']"
  gsettings set "$KEYBINDINGS" switch-input-source-backward "['<Shift>XF86Keyboard']"
}

install_search_light() {
  add_extension "$SEARCH_LIGHT_UUID" search-light
  patch -d "$EXT_DIR" -p0 -i "$REPO_DIR/patches/search-light-blur.patch"
  free_super_space
}

# Ulauncher runs on XWayland and can't grab a global key on Wayland: GNOME runs ulauncher-toggle instead
install_ulauncher() {
  step_ulauncher
  install_kit_files "${ULAUNCHER_FILES[@]}"
  edit_list org.gnome.settings-daemon.plugins.media-keys custom-keybindings add "$LAUNCHER_KEYBINDING/"
  dconf write "$LAUNCHER_KEYBINDING/name" "'Ulauncher'"
  dconf write "$LAUNCHER_KEYBINDING/command" "'ulauncher-toggle'"
  dconf write "$LAUNCHER_KEYBINDING/binding" "'<Super>space'"
  free_super_space
}

remove_ulauncher() {
  pkill -f '^/usr/bin/python3 /usr/bin/ulauncher' || true
  sudo apt-get remove -y ulauncher
  remove_kit_files "${ULAUNCHER_FILES[@]}"
  edit_list org.gnome.settings-daemon.plugins.media-keys custom-keybindings remove "$LAUNCHER_KEYBINDING/"
  dconf reset -f "$LAUNCHER_KEYBINDING/"
}

mod_launcher_status() {
  if extension_installed "$SEARCH_LIGHT_UUID"; then
    echo searchlight
  elif pkg_installed ulauncher; then
    echo ulauncher
  else
    echo none
  fi
}

# installs from before the app can have both launchers: each is checked on its own
mod_launcher_set() {
  local want=$1
  if extension_installed "$SEARCH_LIGHT_UUID" && [[ $want != searchlight ]]; then drop_extension "$SEARCH_LIGHT_UUID" search-light; fi
  if pkg_installed ulauncher && [[ $want != ulauncher ]]; then remove_ulauncher; fi
  case $want in
    searchlight) install_search_light ;;
    ulauncher) install_ulauncher ;;
    none)
      gsettings reset "$KEYBINDINGS" switch-input-source
      gsettings reset "$KEYBINDINGS" switch-input-source-backward
      ;;
  esac
}

step_launcher() { mod_launcher_set searchlight; }

mod_switch_status() { on_off pkg_installed switchcraft; }
mod_switch_install() {
  step_switchcraft
  install_kit_files "${SWITCH_FILES[@]}"
}
mod_switch_remove() {
  # a running Switchcraft keeps calling tahoe-mode.sh until logout
  pkill -x switchcraft || true
  sudo apt-get remove -y switchcraft
  remove_kit_files "${SWITCH_FILES[@]}"
}

mod_ghostty_status() { on_off test -f "$HOME/.local/share/applications/ghostty_ghostty.desktop"; }
mod_ghostty_install() { step_ghostty; }
mod_ghostty_remove() {
  local favorites
  favorites=$(gsettings get org.gnome.shell favorite-apps)
  if [[ $favorites == *"'org.gnome.Terminal.desktop'"* ]]; then
    edit_list org.gnome.shell favorite-apps remove ghostty_ghostty.desktop
  else
    gsettings set org.gnome.shell favorite-apps "${favorites//\'ghostty_ghostty.desktop\'/\'org.gnome.Terminal.desktop\'}"
  fi
  gsettings reset org.gnome.desktop.default-applications.terminal exec
  gsettings reset org.gnome.desktop.default-applications.terminal exec-arg
  sudo apt-get install -y nautilus-extension-gnome-terminal
  rm -f "$HOME/.local/share/nautilus-python/extensions/tahoe-ghostty.py" "$HOME/.local/share/applications/ghostty_ghostty.desktop"
  restore_or_delete "$HOME/.config/ghostty/config"
  restore_or_delete "$HOME/.config/ghostty/tahoe.css"
  rm -f "$HOME"/.config/ghostty/themes/tahoe-{dark,light}
  [[ ! -f $HOME/.bashrc ]] ||
    sed -i 's/xterm-color|\*-256color|xterm-ghostty) color_prompt=yes;;/xterm-color|*-256color) color_prompt=yes;;/' "$HOME/.bashrc"
  sudo snap remove ghostty
}

mod_gtk4_status() {
  local version
  version=$(dpkg-query -W -f='${Version}' libgtk-4-1 2>/dev/null)
  if [[ $version == *+livecss* ]]; then
    echo on
  elif [[ -n $version ]] && dpkg --compare-versions "$version" gt "$GTK4_BASE"; then
    echo unavailable
  else
    echo off
  fi
}
mod_gtk4_install() { TAHOE_YES=1 step_gtk4; }

mod_gdm_status() { on_off test -e "$YARU_GRESOURCE.bak"; }
mod_gdm_install() { TAHOE_YES=1 step_gdm; }

mod_plymouth_status() { on_off test -f "$PLYMOUTH_THEMES/tahoe-logo/tahoe-logo.plymouth"; }
mod_plymouth_install() { TAHOE_YES=1 step_plymouth; }

mod_nvidia_status() {
  if ! grep -qi nvidia <<<"$(lspci)"; then
    echo unavailable
  else
    on_off test -f "$HOME/.config/environment.d/60-gsk-renderer.conf"
  fi
}
mod_nvidia_install() {
  mkdir -p "$HOME/.config/environment.d"
  cp "$REPO_DIR/optional/60-gsk-renderer.conf" "$HOME/.config/environment.d/"
}
mod_nvidia_remove() { rm -f "$HOME/.config/environment.d/60-gsk-renderer.conf"; }

gtk4_stock_version() {
  apt-cache madison libgtk-4-1 | awk -F' *[|] *' '$2 !~ /livecss/ {print $2}' | sort -V | tail -n1
}

mod_gtk4_remove() {
  local version pkg args=()
  version=$(gtk4_stock_version)
  [[ -n $version ]] || { warn "No stock GTK4 in the archive: keeping the patched one."; return "$REFUSED"; }
  for pkg in "${GTK4_PACKAGES[@]}"; do args+=("$pkg=$version"); done
  sudo apt-mark unhold "${GTK4_PACKAGES[@]}"
  if ! sudo apt-get install -y --allow-downgrades "${args[@]}" ||
    [[ "$(dpkg-query -W -f='${Version}' libgtk-4-1)" == *+livecss* ]]; then
    sudo apt-mark hold "${GTK4_PACKAGES[@]}"
    die "GTK4 is still the patched one: held again."
  fi
}

mod_gdm_remove() {
  if [[ -x $CACHE/MacTahoe-gtk-theme/tweaks.sh ]]; then
    (cd "$CACHE/MacTahoe-gtk-theme" && sudo ./tweaks.sh -g -r)
  else
    sudo mv -f "$YARU_GRESOURCE.bak" "$YARU_GRESOURCE"
  fi
  sudo update-alternatives --set gdm-theme.gresource "$YARU_GRESOURCE"
  [[ ! -e $YARU_GRESOURCE.bak ]] || die "The login screen still has the MacTahoe theme."
}

mod_plymouth_remove() {
  local bgrt=$PLYMOUTH_THEMES/bgrt/bgrt.plymouth ours=$PLYMOUTH_THEMES/tahoe-logo/tahoe-logo.plymouth
  [[ -f $bgrt ]] || { warn "Ubuntu's boot splash (bgrt) is missing: keeping the kit's."; return "$REFUSED"; }
  sudo update-alternatives --set default.plymouth "$bgrt"
  if ! sudo update-initramfs -u; then
    sudo update-alternatives --set default.plymouth "$ours"
    die "Could not rebuild the initramfs: the kit's boot splash stays."
  fi
  sudo update-alternatives --remove default.plymouth "$ours"
  sudo rm -rf "$PLYMOUTH_THEMES/tahoe-logo"
}
