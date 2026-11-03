load helpers

@test "packages: one apt-get install with the kit dependencies" {
  load_lib
  run step_packages
  [ "$status" -eq 0 ]
  [ "$(grep -c '^sudo apt-get install' "$CALLS")" -eq 1 ]
  for p in git sassc libglib2.0-dev-bin jq wmctrl x11-utils imagemagick curl; do
    grep -q "^sudo apt-get install -y .*\b$p\b" "$CALLS"
  done
}

@test "upstream: clones once, then only fetches and checks out the pinned commits" {
  load_lib
  run step_upstream
  [ "$(grep -c ' clone ' "$CALLS")" -eq 2 ]
  mkdir -p "$CACHE"/MacTahoe-{gtk,icon}-theme/.git && : >"$CALLS"
  run step_upstream
  [ "$status" -eq 0 ]
  ! grep -q ' clone ' "$CALLS"
  grep -q "checkout --quiet --detach 1e45e19f510edb8cde18fa84d6cd5319f60b086b" "$CALLS"
  grep -q "checkout --quiet --detach 839848b9a8a38a92a6936e30c4abe35cc6f2546d" "$CALLS"
}
