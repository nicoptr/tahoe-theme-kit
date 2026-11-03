load helpers

GTK4_PACKAGES_RE='libgtk-4-1 libgtk-4-bin libgtk-4-common gir1.2-gtk-4.0 libgtk-4-media-gstreamer'

sources_fixture() {
  export APT_SOURCES=$BATS_TEST_TMPDIR/ubuntu.sources
  printf 'Types: deb\nURIs: a\n\nTypes: deb deb-src\nURIs: b\n' >"$APT_SOURCES"
}

@test "gtk4: already patched → nothing to do" {
  load_lib
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.10+livecss1 run step_gtk4
  [ "$status" -eq 0 ]
  refute grep -q '^sudo' "$CALLS"
  refute grep -q '^curl' "$CALLS"
}

@test "gtk4: base version → prebuilt debs installed and held" {
  load_lib
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.10 run step_gtk4 <<<"y"
  [ "$status" -eq 0 ]
  grep -q "^curl .*/releases/download/gtk4-livecss-4.14.5-0ubuntu0.10/gtk4-livecss-debs.tar" "$CALLS"
  grep -q "^sudo apt-get install -y $CACHE/gtk4-debs/" "$CALLS"
  grep -qx "sudo apt-mark hold $GTK4_PACKAGES_RE" "$CALLS"
  [[ "$output" == *"security updates"* ]]
}

@test "gtk4: older version also gets the prebuilt debs" {
  load_lib
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.8 run step_gtk4 <<<"y"
  grep -q "^curl .*gtk4-livecss-debs.tar" "$CALLS"
}

@test "gtk4: newer version and no to the build → no apt call" {
  load_lib
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.11 run step_gtk4 <<<"n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Build patched GTK4"* ]]
  refute grep -q '^sudo' "$CALLS"
  refute grep -q '^curl' "$CALLS"
}

@test "gtk4: newer version and yes → build, install, hold, clean up" {
  load_lib
  sources_fixture
  fake=$BATS_TEST_TMPDIR/build.sh
  printf '#!/usr/bin/env bash\necho "build.sh BUILD_DIR=$BUILD_DIR" >>"$CALLS"\n' >"$fake" && chmod +x "$fake"
  GTK4_BUILD_SCRIPT=$fake
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.11 run step_gtk4 <<<$'y\ny'
  [ "$status" -eq 0 ]
  grep -q "^sudo apt-get build-dep -y gtk4" "$CALLS"
  grep -q "^build.sh BUILD_DIR=$CACHE/gtk4-build" "$CALLS"
  grep -qx "sudo apt-mark hold $GTK4_PACKAGES_RE" "$CALLS"
  grep -qx "sudo cp $CACHE/ubuntu.sources.orig $APT_SOURCES" "$CALLS"
}

@test "gtk4: no to installing the patched GTK4 → nothing installed" {
  load_lib
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.10 run step_gtk4 <<<"n"
  [ "$status" -eq 0 ]
  refute grep -q '^sudo' "$CALLS"
}

@test "gtk4: download failure skips the step without stopping the installer" {
  load_lib
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.10 STUB_RC_CURL=22 run strict step_gtk4 <<<"y"
  [ "$status" -eq 0 ]
  [[ "$output" == *Skipped* ]]
  refute grep -q '^sudo' "$CALLS"
}

@test "gtk4: checksum mismatch → nothing installed" {
  load_lib
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.10 STUB_RC_SHA256SUM=1 run strict step_gtk4 <<<"y"
  [ "$status" -eq 0 ]
  refute grep -q '^sudo' "$CALLS"
}

@test "gtk4: a failed build puts the apt sources back as they were" {
  load_lib
  sources_fixture
  export GTK4_BUILD_SCRIPT=$BATS_TEST_TMPDIR/build.sh
  printf '#!/usr/bin/env bash\nexit 1\n' >"$GTK4_BUILD_SCRIPT" && chmod +x "$GTK4_BUILD_SCRIPT"
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.11 run strict step_gtk4 <<<"y"
  [ "$status" -ne 0 ]
  cmp -s "$CACHE/ubuntu.sources.orig" "$APT_SOURCES"
  grep -qx "sudo cp $CACHE/ubuntu.sources.orig $APT_SOURCES" "$CALLS"
}

@test "gtk4: old debs in the cache are not installed" {
  load_lib
  mkdir -p "$CACHE/gtk4-debs" && : >"$CACHE/gtk4-debs/stale.deb"
  STUB_OUT_DPKG_QUERY=4.14.5+ds-0ubuntu0.10 run step_gtk4 <<<"y"
  [ "$status" -eq 0 ]
  [ ! -e "$CACHE/gtk4-debs/stale.deb" ]
}
