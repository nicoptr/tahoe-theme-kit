# uuid and extensions.gnome.org version_tag; the tag pins the tested release (version in the README)
EXTENSIONS=(
  "user-theme@gnome-shell-extensions.gcampax.github.com 61748"
  "blur-my-shell@aunetx 77413"
  "rounded-window-corners@fxgn 65276"
  "hidetopbar@mathieu.bidon.ca 76242"
  "CoverflowAltTab@palatis.blogspot.com 61982"
)
WOBBLY="compiz-windows-effect@hermes83.github.com 67396"
EXTENSION_SETTINGS=(blur-my-shell rounded-window-corners-reborn hidetopbar appindicator)

install_extension() {
  local uuid=$1 tag=$2 zip=$CACHE/downloads/$1.zip
  curl -fsSL -o "$zip" "https://extensions.gnome.org/download-extension/$uuid.shell-extension.zip?version_tag=$tag" ||
    die "Download failed: $uuid"
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
  local selected=("${EXTENSIONS[@]}") wobbly=false entry uuid tag uuids=() p
  ask_yes_no "Wobbly windows (Compiz windows effect)?" y && wobbly=true
  $wobbly && selected+=("$WOBBLY")

  mkdir -p "$CACHE/downloads"
  for entry in "${selected[@]}"; do
    read -r uuid tag <<<"$entry"
    install_extension "$uuid" "$tag"
    uuids+=("$uuid")
  done
  if $wobbly; then
    patch -d "$HOME/.local/share/gnome-shell/extensions" -p0 -i "$REPO_DIR/patches/compiz-windows-effect-rwc-shadow.patch"
  fi
  enable_extensions "${uuids[@]}"

  for p in "${EXTENSION_SETTINGS[@]}"; do
    dconf reset -f "/org/gnome/shell/extensions/$p/"
    dconf load "/org/gnome/shell/extensions/$p/" <"$REPO_DIR/dconf/$p.dconf"
  done
}
