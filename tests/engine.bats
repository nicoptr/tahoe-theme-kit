load helpers

setup_engine() {
  load_lib
  source "$REPO_DIR/lib/modules.sh"
  source "$REPO_DIR/lib/engine.sh"
  FAKE_STATE=$BATS_TEST_TMPDIR/state
  mkdir -p "$FAKE_STATE"
  local id
  for id in "${MODULES[@]}"; do
    eval "mod_${id}_status() { cat \"$FAKE_STATE/$id\" 2>/dev/null || echo off; }"
    eval "mod_${id}_install() { echo install $id >>\"$CALLS\"; echo on >\"$FAKE_STATE/$id\"; }"
    eval "mod_${id}_remove() { echo remove $id >>\"$CALLS\"; echo off >\"$FAKE_STATE/$id\"; }"
  done
  engine_prepare() { echo prepare >>"$CALLS"; }
}

@test "engine: status prints JSON with every module" {
  setup_engine
  echo on >"$FAKE_STATE/dock"
  run engine_status
  [ "$status" -eq 0 ]
  python3 -I -c '
import json, sys
s = json.loads(sys.argv[1])
assert sorted(s["modules"]) == sorted(sys.argv[2].split()), s
assert s["modules"]["dock"] == "on"
assert s["variant"] is None' "$output" "${MODULES[*]}"
}

@test "engine: status reads the variant and images from tahoe.conf" {
  setup_engine
  mkdir -p "$RUNTIME"
  printf 'VARIANT=topaz\nBG_LIGHT=/a.png\nBG_DARK=/b.png\nPLYMOUTH_LOGO=/c.png\n' >"$RUNTIME/tahoe.conf"
  run engine_status
  python3 -I -c '
import json, sys
s = json.loads(sys.argv[1])
assert (s["variant"], s["bg_light"], s["bg_dark"], s["logo"]) == ("topaz", "/a.png", "/b.png", "/c.png"), s' "$output"
}

@test "engine: apply removes first (reverse order), then installs in MODULES order" {
  setup_engine
  echo on >"$FAKE_STATE/ghostty"
  echo on >"$FAKE_STATE/dock"
  run engine_apply --variant amethyst theme=on ghostty=off dock=off gdm=on
  [ "$status" -eq 0 ]
  [ "$(grep -E '^(install|remove)' "$CALLS" | paste -sd,)" = "remove ghostty,remove dock,install theme,install gdm" ]
  grep -qx '@@ok theme' <<<"$output"
}

@test "engine: modules already in the wanted state are left alone" {
  setup_engine
  echo on >"$FAKE_STATE/dock"
  run engine_apply --variant amethyst dock=on wobbly=off
  [ "$status" -eq 0 ]
  refute grep -qE '^(install|remove)' "$CALLS"
  refute grep -q prepare "$CALLS"
}

@test "engine: apply stops at the first failing module and rolls it back" {
  setup_engine
  mod_corners_install() { echo install corners >>"$CALLS"; return 1; }
  run engine_apply --variant amethyst dock=on corners=on gdm=on
  [ "$status" -eq 1 ]
  grep -qx '@@fail corners' <<<"$output"
  grep -qx 'remove corners' "$CALLS"
  refute grep -q 'install gdm' "$CALLS"
}

@test "engine: a remove refused before any change is not rolled back" {
  setup_engine
  echo on >"$FAKE_STATE/gtk4"
  mod_gtk4_remove() { echo remove gtk4 >>"$CALLS"; return "$REFUSED"; }
  run engine_apply gtk4=off
  [ "$status" -eq 1 ]
  grep -qx '@@fail gtk4' <<<"$output"
  refute grep -q 'install gtk4' "$CALLS"
}

@test "engine: theme off also turns the switch off" {
  setup_engine
  echo on >"$FAKE_STATE/theme"
  echo on >"$FAKE_STATE/switch"
  run engine_apply theme=off
  [ "$status" -eq 0 ]
  [ "$(grep -E '^remove' "$CALLS" | paste -sd,)" = "remove switch,remove theme" ]
}

@test "engine: launcher choice runs mod_launcher_set" {
  setup_engine
  mod_launcher_set() { echo "launcher $1" >>"$CALLS"; }
  echo searchlight >"$FAKE_STATE/launcher"
  run engine_apply --variant amethyst launcher=ulauncher
  [ "$status" -eq 0 ]
  grep -qx 'launcher ulauncher' "$CALLS"
}

@test "engine: installing without a variant anywhere is an error" {
  setup_engine
  run engine_apply dock=on
  [ "$status" -eq 2 ]
  [[ "$output" == *variant* ]]
}

@test "engine: unknown module is an error before anything runs" {
  setup_engine
  run engine_apply --variant amethyst dockk=on
  [ "$status" -eq 2 ]
  refute grep -q prepare "$CALLS"
}

@test "engine: a new variant reinstalls the modules that use it" {
  setup_engine
  mkdir -p "$RUNTIME"
  echo VARIANT=amethyst >"$RUNTIME/tahoe.conf"
  echo on >"$FAKE_STATE/theme"
  echo on >"$FAKE_STATE/dock"
  run engine_apply --variant topaz
  [ "$status" -eq 0 ]
  grep -qx 'install theme' "$CALLS"
  refute grep -q 'install dock' "$CALLS"
}

@test "sudo uses -A when SUDO_ASKPASS is set" {
  load_lib
  SUDO_ASKPASS=/x/askpass sudo apt-get update
  grep -qx 'sudo -A apt-get update' "$CALLS"
  unset SUDO_ASKPASS
  sudo true
  grep -qx 'sudo true' "$CALLS"
}

@test "engine: a refused remove says so with @@refused" {
  setup_engine
  echo on >"$FAKE_STATE/gtk4"
  mod_gtk4_remove() { return "$REFUSED"; }
  run engine_apply gtk4=off
  grep -qx '@@refused gtk4' <<<"$output"
}

@test "engine: a rollback that fails too says so with @@rollback-failed" {
  setup_engine
  mod_corners_install() { return 1; }
  mod_corners_remove() { return 1; }
  run engine_apply --variant amethyst corners=on
  grep -qx '@@rollback-failed corners' <<<"$output"
}

@test "engine: a remove-only apply still has the variant loaded for the rollback" {
  setup_engine
  mkdir -p "$RUNTIME"
  printf 'VARIANT=amethyst\nACCENT=purple\n' >"$RUNTIME/tahoe.conf"
  echo on >"$FAKE_STATE/theme"
  mod_theme_remove() { return 1; }
  mod_theme_install() { echo "rollback accent ${ACCENT:-missing}" >>"$CALLS"; }
  run engine_apply theme=off
  grep -qx 'rollback accent purple' "$CALLS"
}

@test "engine: modules see the variant that prepare wrote" {
  setup_engine
  engine_prepare() { mkdir -p "$RUNTIME"; printf 'VARIANT=topaz\nACCENT=yellow\n' >"$RUNTIME/tahoe.conf"; }
  mod_dock_install() { echo "install accent ${ACCENT:-missing}" >>"$CALLS"; }
  run engine_apply --variant topaz dock=on
  [ "$status" -eq 0 ]
  grep -qx 'install accent yellow' "$CALLS"
}

@test "engine: modules get a TERM when the app runs without a terminal" {
  setup_engine
  unset TERM
  mod_dock_install() { echo "term ${TERM:-missing}" >>"$CALLS"; }
  run engine_apply --variant amethyst dock=on
  grep -qx 'term dumb' "$CALLS"
}
