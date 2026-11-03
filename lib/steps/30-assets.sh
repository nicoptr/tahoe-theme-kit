PLYMOUTH_DEFAULT=${PLYMOUTH_DEFAULT:-/usr/share/plymouth/ubuntu-logo.png}

# MacTahoe's GDM step passes the wallpaper path unquoted, so copies get names without spaces
copy_asset() {
  local src=$1 name dest
  if [[ $(dirname "$src") -ef $RUNTIME/backgrounds ]]; then
    echo "$src"
    return 0
  fi
  name=$(basename "$src")
  dest=$RUNTIME/backgrounds/$2-${name//[^A-Za-z0-9._-]/-}
  cp "$src" "$dest"
  echo "$dest"
}

previous_or() {
  local value
  value=$([[ -f $RUNTIME/tahoe.conf ]] && source "$RUNTIME/tahoe.conf" && echo "${!1:-}")
  if [[ -f $value ]]; then echo "$value"; else echo "$2"; fi
}

step_assets() {
  local wallpapers=$CACHE/MacTahoe-gtk-theme/wallpaper light dark logo
  light=$(ask_image "Light wallpaper" "$(previous_or BG_LIGHT "$wallpapers/MacTahoe-day.jpeg")")
  dark=$(ask_image "Dark wallpaper (also the login screen)" "$(previous_or BG_DARK "$wallpapers/MacTahoe-night.jpeg")")
  logo=$(ask_image "Boot splash logo (PNG, transparent background, light on black)" "$(previous_or PLYMOUTH_LOGO "$PLYMOUTH_DEFAULT")")

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
