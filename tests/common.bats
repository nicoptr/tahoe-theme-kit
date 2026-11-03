load helpers

@test "render substitutes the five tokens and keeps unknown ones" {
  load_lib
  ACCENT=purple ACCENT_HEX='#7a3f84' ICON_THEME=MacTahoe-purple RUNTIME=/r
  printf '@ACCENT@ @ACCENT_HEX@ @ICON_THEME@ @HOME@ @RUNTIME@ @OTHER@ a&b\n' >"$BATS_TEST_TMPDIR/in"
  render "$BATS_TEST_TMPDIR/in" "$BATS_TEST_TMPDIR/out"
  [ "$(cat "$BATS_TEST_TMPDIR/out")" = "purple #7a3f84 MacTahoe-purple $HOME /r @OTHER@ a&b" ]
}

@test "render keeps & in values literal" {
  load_lib
  ACCENT='a&b' ACCENT_HEX= ICON_THEME= RUNTIME=
  echo '@ACCENT@' >"$BATS_TEST_TMPDIR/in"
  render "$BATS_TEST_TMPDIR/in" "$BATS_TEST_TMPDIR/out"
  [ "$(cat "$BATS_TEST_TMPDIR/out")" = 'a&b' ]
}

@test "ask_yes_no: empty answer returns the default" {
  load_lib
  run ask_yes_no "Go?" y <<<""
  [ "$status" -eq 0 ]
  run ask_yes_no "Go?" n <<<""
  [ "$status" -eq 1 ]
}

@test "ask_yes_no: n returns 1, y returns 0, junk asks again" {
  load_lib
  run ask_yes_no "Go?" y <<<"n"
  [ "$status" -eq 1 ]
  run ask_yes_no "Go?" n <<<$'maybe\ny'
  [ "$status" -eq 0 ]
}

@test "ask_yes_no: TAHOE_YES=1 answers the default without reading stdin" {
  load_lib
  TAHOE_YES=1 run ask_yes_no "Go?" n <<<"y"
  [ "$status" -eq 1 ]
}
