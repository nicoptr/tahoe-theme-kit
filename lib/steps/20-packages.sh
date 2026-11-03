PACKAGES=(git sassc libglib2.0-dev-bin jq wmctrl x11-utils imagemagick curl python3-nautilus)

step_packages() {
  sudo apt-get update
  sudo apt-get install -y "${PACKAGES[@]}"
}

clone_pinned() {
  local dir=$CACHE/$1 commit=$2
  [[ -d $dir/.git ]] || git clone "https://github.com/vinceliuice/$1.git" "$dir"
  git -C "$dir" fetch --quiet origin
  git -C "$dir" checkout --quiet --detach "$commit"
}

step_upstream() {
  source "$REPO_DIR/upstream.lock"
  mkdir -p "$CACHE"
  clone_pinned MacTahoe-gtk-theme "$MACTAHOE_GTK_COMMIT"
  clone_pinned MacTahoe-icon-theme "$MACTAHOE_ICON_COMMIT"
}
