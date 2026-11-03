load helpers

image() { mkdir -p "$(dirname "$1")" && convert -size 4x4 xc:red "$1"; }

setup_assets() {
  load_lib
  source "$REPO_DIR/variants/amethyst.conf"
  VARIANT_CONF=$REPO_DIR/variants/amethyst.conf
  image "$CACHE/MacTahoe-gtk-theme/wallpaper/MacTahoe-day.jpeg"
  image "$CACHE/MacTahoe-gtk-theme/wallpaper/MacTahoe-night.jpeg"
  PLYMOUTH_DEFAULT=$BATS_TEST_TMPDIR/ubuntu-logo.png
  image "$PLYMOUTH_DEFAULT"
}

@test "assets: defaults go to tahoe.conf as absolute copied paths" {
  setup_assets
  run step_assets <<<$'\n\n\n'
  [ "$status" -eq 0 ]
  source "$RUNTIME/tahoe.conf"
  [ "$BG_LIGHT" = "$RUNTIME/backgrounds/light-MacTahoe-day.jpeg" ]
  [ "$BG_DARK" = "$RUNTIME/backgrounds/dark-MacTahoe-night.jpeg" ]
  [ "$PLYMOUTH_LOGO" = "$RUNTIME/backgrounds/logo-ubuntu-logo.png" ]
  [ -f "$BG_LIGHT" ] && [ -f "$BG_DARK" ] && [ -f "$PLYMOUTH_LOGO" ]
  [ "$ACCENT" = purple ]
  [ -x "$RUNTIME/tahoe-mode.sh" ] && [ -f "$RUNTIME/gen-themes.py" ] && [ -f "$RUNTIME/restack-below.py" ]
}

@test "assets: ~ and spaces in the path work" {
  setup_assets
  image "$HOME/My Pics/a b.png"
  run step_assets <<<$'~/My Pics/a b.png\n\n\n'
  [ "$status" -eq 0 ]
  source "$RUNTIME/tahoe.conf"
  [ "$BG_LIGHT" = "$RUNTIME/backgrounds/light-a-b.png" ]
  [ -f "$BG_LIGHT" ]
}

@test "assets: a file that is not an image is asked again" {
  setup_assets
  echo text >"$HOME/notes.txt"
  run step_assets <<<$'~/notes.txt\n\n\n\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Not an image"* ]]
  source "$RUNTIME/tahoe.conf"
  [ "$BG_LIGHT" = "$RUNTIME/backgrounds/light-MacTahoe-day.jpeg" ]
}

@test "assets: rerun overwrites tahoe.conf and accepts the already copied file" {
  setup_assets
  run step_assets <<<$'\n\n\n'
  run step_assets <<<$"$RUNTIME/backgrounds/light-MacTahoe-day.jpeg"$'\n\n\n'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^BG_LIGHT=' "$RUNTIME/tahoe.conf")" -eq 1 ]
  [ "$(grep -c '^ACCENT=' "$RUNTIME/tahoe.conf")" -eq 1 ]
}

@test "assets: no stdin and an invalid default stops instead of looping" {
  setup_assets
  rm "$PLYMOUTH_DEFAULT"
  export PLYMOUTH_DEFAULT VARIANT_CONF
  run strict step_assets </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not an image: $PLYMOUTH_DEFAULT"* ]]
}

@test "assets: no stdin and valid defaults uses the defaults" {
  setup_assets
  export PLYMOUTH_DEFAULT VARIANT_CONF
  run strict step_assets </dev/null
  [ "$status" -eq 0 ]
  grep -q '^BG_DARK=.*dark-MacTahoe-night.jpeg$' "$RUNTIME/tahoe.conf"
}

@test "assets: a rerun offers the images chosen last time" {
  setup_assets
  image "$HOME/mine-light.png"
  run step_assets <<<$'~/mine-light.png\n\n\n'
  run step_assets <<<$'\n\n\n'
  [ "$status" -eq 0 ]
  source "$RUNTIME/tahoe.conf"
  [ "$BG_LIGHT" = "$RUNTIME/backgrounds/light-mine-light.png" ]
  [ -f "$BG_LIGHT" ]
}
