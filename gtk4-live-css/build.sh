#!/usr/bin/env bash
# Rebuilds Ubuntu's gtk4 with gtk4-user-css-live-reload.patch
# (https://github.com/MainstreamOS/gtk4-live-css), so open GTK4/libadwaita apps
# reload ~/.config/gtk-4.0/gtk.css when tahoe-mode.sh swaps it.
# Needs deb-src enabled and `sudo apt build-dep gtk4`. Rerun after every Ubuntu gtk4 update.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BUILD=${BUILD_DIR:-$HOME/.cache/gtk4-live-css-build}
VERSION=$(apt-cache showsrc gtk4 | awk '/^Version:/{print $2}' | sort -V | tail -1)
LOCAL_VERSION="$VERSION+livecss1"

rm -rf "${BUILD:?}" && mkdir -p "$BUILD" && cd "$BUILD"
apt-get source --download-only "gtk4=$VERSION"
# unpatched tree: dpkg-buildpackage then applies the whole series, ours included
dpkg-source -x --skip-patches gtk4_*.dsc
cd gtk4-*/

cp "$HERE/gtk4-user-css-live-reload.patch" debian/patches/
echo gtk4-user-css-live-reload.patch >>debian/patches/series

{
  printf 'gtk4 (%s) noble; urgency=medium\n\n' "$LOCAL_VERSION"
  printf '  * Reload ~/.config/gtk-4.0/gtk.css while apps are running (gtk4-live-css).\n\n'
  printf ' -- Local build <%s@localhost>  %s\n\n' "$USER" "$(date -R)"
  cat debian/changelog
} >debian/changelog.new
mv debian/changelog.new debian/changelog

DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -b -uc -us

# the patch is the only code in libgtk-4 that calls realpath()
check=$(mktemp -d)
dpkg-deb -x "$BUILD"/libgtk-4-1_*"$LOCAL_VERSION"_amd64.deb "$check"
imports=$(nm -D --undefined-only "$check"/usr/lib/*/libgtk-4.so.1)
if ! grep -qw realpath <<<"$imports"; then
  rm -rf "$check"
  echo "ERROR: built libgtk-4 does not contain the live reload patch" >&2
  exit 1
fi
rm -rf "$check"

echo "Packages for $LOCAL_VERSION are in $BUILD (patch verified)"
