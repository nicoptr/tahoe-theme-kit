REPO_DIR=$(cd "$BATS_TEST_DIRNAME/.." && pwd)

setup() {
  export HOME=$BATS_TEST_TMPDIR/home CALLS=$BATS_TEST_TMPDIR/calls
  export PATH=$REPO_DIR/tests/stubs:$PATH OS_RELEASE=$BATS_TEST_TMPDIR/os-release
  mkdir -p "$HOME" && : >"$CALLS"
  printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"$OS_RELEASE"
  unset XDG_SESSION_TYPE TAHOE_YES
}

load_lib() {
  source "$REPO_DIR/lib/common.sh"
  local f
  for f in "$REPO_DIR"/lib/steps/*.sh; do source "$f"; done
}

calls() { cat "$CALLS"; }
