PLYMOUTH_DEFAULT=${PLYMOUTH_DEFAULT:-/usr/share/plymouth/ubuntu-logo.png}

copy_asset() {
  local src=$1 dest
  dest=$RUNTIME/backgrounds/$2-$(basename "$src")
  [[ $src -ef $dest ]] || cp "$src" "$dest"
  echo "$dest"
}

step_assets() {
  local wallpapers=$CACHE/MacTahoe-gtk-theme/wallpaper light dark logo
  light=$(ask_image "Light wallpaper" "$wallpapers/MacTahoe-day.jpeg")
  dark=$(ask_image "Dark wallpaper (also the login screen)" "$wallpapers/MacTahoe-night.jpeg")
  logo=$(ask_image "Boot splash logo (PNG, transparent background, light on black)" "$PLYMOUTH_DEFAULT")

  mkdir -p "$RUNTIME/backgrounds"
  light=$(copy_asset "$light" light)
  dark=$(copy_asset "$dark" dark)
  logo=$(copy_asset "$logo" logo)

  {
    cat "$VARIANT_CONF"
    printf '\nBG_LIGHT=%q\nBG_DARK=%q\nPLYMOUTH_LOGO=%q\n' "$light" "$dark" "$logo"
  } >"$RUNTIME/tahoe.conf"
  cp "$REPO_DIR"/runtime/* "$REPO_DIR/ghostty/gen-themes.py" "$RUNTIME/"
}
