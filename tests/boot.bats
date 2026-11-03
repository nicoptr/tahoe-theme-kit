load helpers

setup_boot() {
  load_lib
  mkdir -p "$RUNTIME" "$CACHE/MacTahoe-gtk-theme"
  convert -size 4x4 xc:white "$BATS_TEST_TMPDIR/logo.png"
  { cat "$REPO_DIR/variants/amethyst.conf"; printf 'BG_DARK=%q\nPLYMOUTH_LOGO=%q\n' /bg/dark.jpg "$BATS_TEST_TMPDIR/logo.png"; } >"$RUNTIME/tahoe.conf"
  source "$RUNTIME/tahoe.conf"
}

@test "gdm: tweaks.sh without -c, then the Yaru alternative" {
  setup_boot
  run step_gdm <<<"y"
  [ "$status" -eq 0 ]
  grep -qx "sudo ./tweaks.sh -g -b /bg/dark.jpg -p 45 -h smaller -t purple" "$CALLS"
  grep -qx "sudo update-alternatives --set gdm-theme.gresource /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource" "$CALLS"
}

@test "plymouth: theme file gets the accent as 0x color" {
  setup_boot
  plymouth_theme_file "$BATS_TEST_TMPDIR/t.plymouth"
  grep -qx 'ProgressBarForegroundColor=0x7a3f84' "$BATS_TEST_TMPDIR/t.plymouth"
}

@test "plymouth: installs the theme and rebuilds the initramfs" {
  setup_boot
  run step_plymouth <<<"y"
  [ "$status" -eq 0 ]
  grep -qx "sudo update-alternatives --set default.plymouth /usr/share/plymouth/themes/tahoe-logo/tahoe-logo.plymouth" "$CALLS"
  grep -qx "sudo update-initramfs -u" "$CALLS"
}

@test "gdm and plymouth: no → no sudo" {
  setup_boot
  run step_gdm <<<"n"
  run step_plymouth <<<"n"
  refute grep -q '^sudo' "$CALLS"
}

@test "nvidia: no NVIDIA GPU → no question" {
  load_lib
  STUB_OUT_LSPCI='00:02.0 VGA compatible controller: Intel Corporation' run step_nvidia </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *GSK_RENDERER* ]]
}

@test "nvidia: driver not working → warning, continues" {
  load_lib
  STUB_OUT_LSPCI='01:00.0 VGA compatible controller: NVIDIA Corporation GA104' STUB_RC_NVIDIA_SMI=9 run step_nvidia <<<"n"
  [ "$status" -eq 0 ]
  [[ "$output" == *nvidia-smi* ]]
  [ ! -e "$HOME/.config/environment.d/60-gsk-renderer.conf" ]
}

@test "nvidia: yes → GSK_RENDERER=gl installed" {
  load_lib
  STUB_OUT_LSPCI='01:00.0 VGA compatible controller: NVIDIA Corporation GA104' run step_nvidia <<<"y"
  grep -qx 'GSK_RENDERER=gl' "$HOME/.config/environment.d/60-gsk-renderer.conf"
}

@test "finish: switches to dark and prints the manual steps" {
  load_lib
  mkdir -p "$RUNTIME"
  printf '#!/usr/bin/env bash\necho "tahoe-mode.sh $*" >>"$CALLS"\n' >"$RUNTIME/tahoe-mode.sh" && chmod +x "$RUNTIME/tahoe-mode.sh"
  run step_finish
  [ "$status" -eq 0 ]
  grep -qx "tahoe-mode.sh dark" "$CALLS"
  [[ "$output" == *Monitoring* ]]
  [[ "$output" == *"Log out"* ]]
}
