SWITCHCRAFT_URL=https://github.com/kem-a/switchcraft/releases/download/v1.2.1/switchcraft_1.2.1_amd64.deb
SWITCHCRAFT_SHA256=ef58113be813c67f6bc985906522c5d3d7dcfecff776b50713024570b1814c96
ULAUNCHER_URL=https://github.com/Ulauncher/Ulauncher/releases/download/5.16.2/ulauncher_5.16.2_all.deb
ULAUNCHER_SHA256=e6bd4f55a71daf4d3f5bd1a0f8d11d04c80c536938dde4ba3ccc8849049fe788

file_uri() { python3 -I -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$1"; }

install_file() {
  local src=$1 dest=$2 tmp
  tmp=$(mktemp)
  render "$src" "$tmp"
  mkdir -p "$(dirname "$dest")"
  if [[ -f $dest && ! -e $dest.bak-tahoe ]] && ! cmp -s "$tmp" "$dest"; then
    cp "$dest" "$dest.bak-tahoe"
  fi
  cat "$tmp" >"$dest"
  rm -f "$tmp"
}

step_settings() {
  mod_wallpaper_install
  install_kit_files "${THEME_FILES[@]}" "${SWITCH_FILES[@]}"
  systemctl --user enable systemd-tmpfiles-setup.service
}

install_deb() {
  local pkg=$1 url=$2 sha256=$3 deb=$CACHE/downloads/${2##*/}
  if [[ "$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null)" == 'install ok installed' ]]; then
    log "$pkg already installed."
    return 0
  fi
  mkdir -p "$CACHE/downloads"
  download "$url" "$deb" "$sha256" || die "Could not get $pkg"
  sudo apt-get install -y "$deb"
}

step_switchcraft() { install_deb switchcraft "$SWITCHCRAFT_URL" "$SWITCHCRAFT_SHA256"; }
step_ulauncher() { install_deb ulauncher "$ULAUNCHER_URL" "$ULAUNCHER_SHA256"; }
