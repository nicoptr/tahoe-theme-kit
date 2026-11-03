SWITCHCRAFT_DEB=switchcraft_1.2.1_amd64.deb
SWITCHCRAFT_URL=https://github.com/kem-a/switchcraft/releases/download/v1.2.1/$SWITCHCRAFT_DEB

file_uri() { python3 -I -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$1"; }

install_file() {
  local src=$1 dest=$2 tmp
  tmp=$(mktemp)
  render "$src" "$tmp"
  mkdir -p "$(dirname "$dest")"
  if [[ -f $dest && ! -e $dest.bak-tahoe ]] && ! cmp -s "$tmp" "$dest"; then
    cp "$dest" "$dest.bak-tahoe"
  fi
  mv "$tmp" "$dest"
}

step_settings() {
  source "$RUNTIME/tahoe.conf"
  gsettings set org.gnome.desktop.background picture-uri "$(file_uri "$BG_LIGHT")"
  gsettings set org.gnome.desktop.background picture-uri-dark "$(file_uri "$BG_DARK")"
  dconf write /org/gnome/terminal/legacy/theme-variant "'system'"

  local rel
  while IFS= read -r rel; do
    install_file "$REPO_DIR/files/$rel" "$HOME/$rel"
  done < <(cd "$REPO_DIR/files" && find . -type f -printf '%P\n')
  systemctl --user enable systemd-tmpfiles-setup.service
}

step_switchcraft() {
  if [[ "$(dpkg-query -W -f='${Status}' switchcraft 2>/dev/null)" == 'install ok installed' ]]; then
    log "Switchcraft already installed."
    return 0
  fi
  mkdir -p "$CACHE/downloads"
  curl -fsSL -o "$CACHE/downloads/$SWITCHCRAFT_DEB" "$SWITCHCRAFT_URL"
  sudo apt-get install -y "$CACHE/downloads/$SWITCHCRAFT_DEB"
}
