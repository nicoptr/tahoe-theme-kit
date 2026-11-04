load helpers

setup_ext() {
  load_lib
  export STUB_OUT_GSETTINGS="['ubuntu-appindicators@ubuntu.com', 'blur-my-shell@aunetx']"
}

enabled_value() { grep '^gsettings set org.gnome.shell enabled-extensions' "$CALLS" | sed 's/^gsettings set org.gnome.shell enabled-extensions //'; }

@test "extensions: downloads pinned zips and installs them" {
  setup_ext
  run step_extensions <<<"y"
  [ "$status" -eq 0 ]
  grep -q "^curl .*download-extension/blur-my-shell@aunetx.shell-extension.zip?version_tag=77413" "$CALLS"
  grep -q "^gnome-extensions install --force $CACHE/downloads/blur-my-shell@aunetx.zip" "$CALLS"
  [ "$(grep -c '^gnome-extensions install' "$CALLS")" -eq 7 ]
}

@test "extensions: enabled list keeps existing entries and adds each uuid once" {
  setup_ext
  run step_extensions <<<"y"
  value=$(enabled_value)
  [[ "$value" == *"'ubuntu-appindicators@ubuntu.com'"* ]]
  [ "$(grep -o "'blur-my-shell@aunetx'" <<<"$value" | wc -l)" -eq 1 ]
  [[ "$value" == *"'hidetopbar@mathieu.bidon.ca'"* ]]
}

@test "extensions: empty enabled list (@as []) works" {
  setup_ext
  STUB_OUT_GSETTINGS='@as []' run step_extensions <<<"n"
  [ "$status" -eq 0 ]
  [[ "$(enabled_value)" == "['user-theme@gnome-shell-extensions.gcampax.github.com',"* ]]
}

@test "extensions: no wobbly windows → no compiz download, no patch" {
  setup_ext
  run step_extensions <<<"n"
  refute grep -q compiz-windows-effect "$CALLS"
  refute grep -q '^patch.*compiz' "$CALLS"
}

@test "extensions: wobbly windows → patched after install" {
  setup_ext
  run step_extensions <<<"y"
  grep -q "^patch -d $HOME/.local/share/gnome-shell/extensions -p0 -i $REPO_DIR/patches/compiz-windows-effect-rwc-shadow.patch" "$CALLS"
}

@test "extensions: never effect extensions the user rejected" {
  setup_ext
  run step_extensions <<<"y"
  refute grep -qiE 'magic-lamp|burn-my-windows' "$CALLS"
}

@test "extensions: download failure names the extension" {
  setup_ext
  STUB_RC_CURL=22 run strict step_extensions <<<"y"
  [ "$status" -ne 0 ]
  [[ "$output" == *user-theme@gnome-shell-extensions.gcampax.github.com* ]]
}

@test "extensions: settings reset then loaded for the 5 extensions" {
  setup_ext
  run step_extensions <<<"y"
  for p in blur-my-shell rounded-window-corners-reborn hidetopbar appindicator dash-to-dock; do
    grep -qx "dconf reset -f /org/gnome/shell/extensions/$p/" "$CALLS"
    grep -qx "dconf load /org/gnome/shell/extensions/$p/" "$CALLS"
  done
}

@test "extensions: checksum mismatch stops before installing" {
  setup_ext
  STUB_RC_SHA256SUM=1 run strict step_extensions <<<"y"
  [ "$status" -ne 0 ]
  [[ "$output" == *"user-theme@gnome-shell-extensions.gcampax.github.com"* ]]
  refute grep -q '^gnome-extensions install' "$CALLS"
}

