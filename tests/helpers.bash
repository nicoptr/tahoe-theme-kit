REPO_DIR=$(cd "$BATS_TEST_DIRNAME/.." && pwd)

setup() {
  export HOME=$BATS_TEST_TMPDIR/home CALLS=$BATS_TEST_TMPDIR/calls
  export PATH=$REPO_DIR/tests/stubs:$PATH OS_RELEASE=$BATS_TEST_TMPDIR/os-release
  mkdir -p "$HOME" && : >"$CALLS"
  printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"$OS_RELEASE"
  unset XDG_SESSION_TYPE TAHOE_YES SUDO_ASKPASS
  export YARU_GRESOURCE=$BATS_TEST_TMPDIR/yaru/gnome-shell-theme.gresource PLYMOUTH_THEMES=$BATS_TEST_TMPDIR/plymouth
}

load_lib() {
  source "$REPO_DIR/lib/common.sh"
  local f
  for f in "$REPO_DIR"/lib/steps/*.sh; do source "$f"; done
  source "$REPO_DIR/lib/modules.sh"
}

calls() { cat "$CALLS"; }

# runs a step with errexit on, like install.sh does
strict() {
  REPO_DIR=$REPO_DIR bash -euo pipefail -c 'source "$1/lib/common.sh"; for f in "$1"/lib/steps/*.sh; do source "$f"; done; source "$1/lib/modules.sh"; [[ -z ${VARIANT_CONF:-} ]] || source "$VARIANT_CONF"; shift; "$@"' _ "$REPO_DIR" "$@"
}

# a curl that writes $1 to its -o file
fake_curl_writes() {
  FAKE_CURL_CONTENT=$1
  curl() {
    echo "curl $*" >>"$CALLS"
    local out
    while (($#)); do [[ $1 == -o ]] && out=$2; shift; done
    printf '%s' "$FAKE_CURL_CONTENT" >"$out"
  }
}

# `! cmd` does not fail a bats test unless it is the last line
refute() { if "$@"; then return 1; fi; }
