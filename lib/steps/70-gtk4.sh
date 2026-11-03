GTK4_BASE=4.14.5+ds-0ubuntu0.10
GTK4_PACKAGES=(libgtk-4-1 libgtk-4-bin libgtk-4-common gir1.2-gtk-4.0 libgtk-4-media-gstreamer)
GTK4_RELEASE_URL=${GTK4_RELEASE_URL:-https://github.com/nicoptr/tahoe-theme-kit/releases/download/gtk4-livecss-4.14.5-0ubuntu0.10}
GTK4_TAR_SHA256=f7bc8e787ef0878856717676c121eda3cf3c297b8fe525d964b37ea0a31cdc25
GTK4_BUILD_SCRIPT=${GTK4_BUILD_SCRIPT:-$REPO_DIR/gtk4-live-css/build.sh}
APT_SOURCES=/etc/apt/sources.list.d/ubuntu.sources

gtk4_hold_warning() {
  log "Patched GTK4 lets open apps (Nautilus too) switch light/dark live."
  log "It is held with apt-mark: GTK4 updates, security updates included, stop until you unhold it."
}

install_gtk4_prebuilt() {
  local dir=$CACHE/gtk4-debs
  mkdir -p "$dir"
  download "$GTK4_RELEASE_URL/gtk4-livecss-debs.tar" "$CACHE/downloads/gtk4-livecss-debs.tar" "$GTK4_TAR_SHA256" || return 1
  tar -xf "$CACHE/downloads/gtk4-livecss-debs.tar" -C "$dir"
  sudo apt-get install -y "$dir"/*.deb
}

build_gtk4() {
  local build=$CACHE/gtk4-build manual_before pkg debs=()
  manual_before=$(apt-mark showmanual)
  sudo sed -i 's/^Types: deb$/Types: deb deb-src/' "$APT_SOURCES"
  sudo apt-get update
  sudo apt-get build-dep -y gtk4
  BUILD_DIR=$build "$GTK4_BUILD_SCRIPT"

  for pkg in "${GTK4_PACKAGES[@]}"; do debs+=("$build/${pkg}"_*+livecss1_*.deb); done
  sudo apt-get install -y "${debs[@]}"

  comm -13 <(sort <<<"$manual_before") <(apt-mark showmanual | sort) | xargs -r sudo apt-mark auto
  sudo apt-get autoremove -y
  sudo sed -i 's/^Types: deb deb-src$/Types: deb/' "$APT_SOURCES"
  sudo apt-get update
  rm -rf "${build:?}"
}

step_gtk4() {
  local version
  version=$(dpkg-query -W -f='${Version}' libgtk-4-1 2>/dev/null)
  if [[ $version == *+livecss* ]]; then
    log "GTK4 already has the live CSS patch."
    return 0
  fi

  gtk4_hold_warning
  if dpkg --compare-versions "$version" le "$GTK4_BASE"; then
    ask_yes_no "Install the patched GTK4 ($GTK4_BASE)?" y || return 0
    mkdir -p "$CACHE/downloads"
    if ! install_gtk4_prebuilt; then
      log "Skipped: Nautilus gets restarted on every light/dark switch instead."
      return 0
    fi
  else
    log "Installed GTK4 $version is newer than the prebuilt $GTK4_BASE."
    if ! ask_yes_no "Build patched GTK4 from source (about 45 minutes)?" n; then
      log "Skipped: Nautilus gets restarted on every light/dark switch instead."
      return 0
    fi
    build_gtk4
  fi
  sudo apt-mark hold "${GTK4_PACKAGES[@]}"
}
