# uuid, extensions.gnome.org version_tag (pins the tested release, versions in the README), sha256 of the zip
EXTENSIONS=(
  "user-theme@gnome-shell-extensions.gcampax.github.com 61748 3a81c880cada5b8e18d30f0ec65a16a44bf88cdca51038a0af5ed48e63cbfa98"
  "blur-my-shell@aunetx 77413 3218766acf4b0feed700ba518a1db5616f59c7e1036758ffbd18bf4743e9b2db"
  "rounded-window-corners@fxgn 65276 7e2271cc9717e7f7900825d2d8f85dd77e9085679814d1c8590010cfe2a041a4"
  "hidetopbar@mathieu.bidon.ca 76242 c4bccf4e9517c429d1de88c0263037b4ab73804f7024f2376c2419e186892200"
  "dash-to-dock@micxgx.gmail.com 76105 b05003e79835a35451e94931539ba1977f2a7a93b652a4fc6b7be60a77c18ae1"
  "CoverflowAltTab@palatis.blogspot.com 61982 0d5a430205a88e807d94a41b7849dd4b027219c9df36892d7cbfb3db948d089e"
  "search-light@icedman.github.com 63847 3f3e486a88bab5f33962efb28e6651b199b1d15ef89275f5756dcd8c3fac4ffc"
)
WOBBLY="compiz-windows-effect@hermes83.github.com 67396 744d0f98858dac57bdcff50c399d63a9aea7b1db1c5765a967081cc7802fad0e"
EXTENSION_SETTINGS=(blur-my-shell rounded-window-corners-reborn hidetopbar appindicator dash-to-dock search-light)

install_extension() {
  local uuid=$1 tag=$2 sha256=$3 zip=$CACHE/downloads/$1.zip
  download "https://extensions.gnome.org/download-extension/$uuid.shell-extension.zip?version_tag=$tag" "$zip" "$sha256" ||
    die "Could not get the extension $uuid"
  gnome-extensions install --force "$zip"
}

enable_extensions() {
  local current
  current=$(gsettings get org.gnome.shell enabled-extensions)
  gsettings set org.gnome.shell enabled-extensions "$(python3 -I -c '
import ast, sys
enabled = ast.literal_eval(sys.argv[1].removeprefix("@as "))
print(enabled + [u for u in sys.argv[2:] if u not in enabled])' "$current" "$@")"
}

step_extensions() {
  local selected=("${EXTENSIONS[@]}") wobbly=false entry uuid tag sha256 uuids=() p
  ask_yes_no "Wobbly windows (Compiz windows effect)?" y && wobbly=true
  $wobbly && selected+=("$WOBBLY")

  mkdir -p "$CACHE/downloads"
  for entry in "${selected[@]}"; do
    read -r uuid tag sha256 <<<"$entry"
    install_extension "$uuid" "$tag" "$sha256"
    uuids+=("$uuid")
  done
  if $wobbly; then
    patch -d "$HOME/.local/share/gnome-shell/extensions" -p0 -i "$REPO_DIR/patches/compiz-windows-effect-rwc-shadow.patch"
  fi
  patch -d "$HOME/.local/share/gnome-shell/extensions" -p0 -i "$REPO_DIR/patches/search-light-dark-wallpaper.patch"
  enable_extensions "${uuids[@]}"

  for p in "${EXTENSION_SETTINGS[@]}"; do
    dconf reset -f "/org/gnome/shell/extensions/$p/"
    dconf load "/org/gnome/shell/extensions/$p/" <"$REPO_DIR/dconf/$p.dconf"
  done
  # Super+Space belongs to Search Light; the layout switch keeps the keyboard's own key
  gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['XF86Keyboard']"
  gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift>XF86Keyboard']"
}
