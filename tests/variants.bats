load helpers

contrast() {
  python3 -I - "$1" "$2" <<'PY'
import sys
def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
a, b = sorted((lum(sys.argv[1]), lum(sys.argv[2])), reverse=True)
print(f"{(a + 0.05) / (b + 0.05):.2f}")
PY
}

@test "every variant defines the 7 keys with valid values" {
  for conf in "$REPO_DIR"/variants/*.conf; do
    (
      source "$conf"
      [[ " blue purple pink red orange yellow green grey " == *" $ACCENT "* ]]
      [[ $ACCENT_HEX =~ ^#[0-9a-fA-F]{6}$ ]]
      [ -n "$ICON_THEME" ]
      [ "${#TERMINAL_DARK[@]}" -eq 5 ] && [ "${#TERMINAL_LIGHT[@]}" -eq 5 ]
      [ "$(grep -o "#[0-9a-fA-F]\{6\}" <<<"$TERMINAL_DARK_PALETTE" | wc -l)" -eq 16 ]
      [ "$(grep -o "#[0-9a-fA-F]\{6\}" <<<"$TERMINAL_LIGHT_PALETTE" | wc -l)" -eq 16 ]
    ) || { echo "bad variant: $conf"; return 1; }
  done
}

@test "terminal foreground has at least 4.5:1 contrast in both modes" {
  for conf in "$REPO_DIR"/variants/*.conf; do
    source "$conf"
    for mode in DARK LIGHT; do
      local -n c=TERMINAL_$mode
      ratio=$(contrast "${c[0]}" "${c[1]}")
      awk -v r="$ratio" 'BEGIN{exit !(r >= 4.5)}' || { echo "$conf $mode: $ratio"; return 1; }
    done
  done
}

@test "usage lists the variants" {
  run "$REPO_DIR/install.sh"
  [[ "$output" == *amethyst* ]]
}
