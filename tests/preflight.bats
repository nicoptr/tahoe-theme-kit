load helpers

@test "no variant: usage, exit 2, no sudo" {
  run "$REPO_DIR/install.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *Usage* ]]
  refute grep -q '^sudo' "$CALLS"
}

@test "unknown variant: usage, exit 2, no sudo" {
  run "$REPO_DIR/install.sh" rubyy
  [ "$status" -eq 2 ]
  [[ "$output" == *Usage* ]]
  refute grep -q '^sudo' "$CALLS"
}

@test "not Ubuntu 24.04: exit 1" {
  load_lib
  printf 'ID=ubuntu\nVERSION_ID="26.04"\n' >"$OS_RELEASE"
  run step_preflight
  [ "$status" -eq 1 ]
  [[ "$output" == *"Ubuntu 24.04"* ]]
}

@test "root: exit 1" {
  load_lib
  STUB_OUT_ID=0 run step_preflight
  [ "$status" -eq 1 ]
  [[ "$output" == *root* ]]
}

@test "wayland: a note, no question" {
  load_lib
  XDG_SESSION_TYPE=wayland run step_preflight </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *Wayland* ]]
  [[ "$output" != *"[y/N]"* ]]
}

@test "success: sudo -v asked exactly once" {
  load_lib
  run step_preflight
  [ "$status" -eq 0 ]
  [ "$(grep -c '^sudo -v$' "$CALLS")" -eq 1 ]
}
