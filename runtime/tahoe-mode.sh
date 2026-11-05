#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  dark) MODE=Dark ;;
  light) MODE=Light ;;
  *) echo "usage: $0 dark|light" >&2; exit 1 ;;
esac

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$KIT_DIR/tahoe.conf"

THEME="MacTahoe-$MODE-$ACCENT"
# the theme was turned off: nothing to switch
[[ -d $HOME/.themes/$THEME ]] || exit 0
ICONS="$ICON_THEME-${1}"
GTK4_DIR="$HOME/.config/gtk-4.0"
USER_THEME_SCHEMAS="$HOME/.local/share/gnome-shell/extensions/user-theme@gnome-shell-extensions.gcampax.github.com/schemas"

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tahoe-mode.lock"
flock -w 15 9

set_if_changed() {
  local schema=$1 key=$2 value=$3
  shift 3
  [[ "$(gsettings "$@" get "$schema" "$key")" == "'$value'" ]] && return 0
  gsettings "$@" set "$schema" "$key" "$value"
}

wait_gone() {
  for _ in {1..50}; do
    pgrep "$@" >/dev/null || return 0
    sleep 0.1
  done
}

apply_terminal() {
  local uuid profile palette
  local -a c
  uuid=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
  profile="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$uuid/"

  if [[ $MODE == Dark ]]; then
    c=("${TERMINAL_DARK[@]}"); palette=$TERMINAL_DARK_PALETTE
  else
    c=("${TERMINAL_LIGHT[@]}"); palette=$TERMINAL_LIGHT_PALETTE
  fi

  gsettings set "$profile" use-theme-colors false
  gsettings set "$profile" background-color "${c[0]}"
  gsettings set "$profile" foreground-color "${c[1]}"
  gsettings set "$profile" palette "$palette"
  gsettings set "$profile" bold-color-same-as-fg true
  gsettings set "$profile" bold-is-bright false
  gsettings set "$profile" use-transparent-background true
  gsettings set "$profile" use-theme-transparency false
  gsettings set "$profile" background-transparency-percent "${c[4]}"
  gsettings set "$profile" cursor-colors-set true
  gsettings set "$profile" cursor-background-color "${c[2]}"
  gsettings set "$profile" cursor-foreground-color "${c[0]}"
  gsettings set "$profile" highlight-colors-set true
  gsettings set "$profile" highlight-background-color "${c[3]}"
  gsettings set "$profile" highlight-foreground-color "${c[1]}"
}

apply_ulauncher() {
  local settings="$HOME/.config/ulauncher/settings.json" tmp
  [[ -f "$settings" ]] || return 0
  [[ "$(jq -r '."theme-name"' "$settings")" == "$1" ]] && return 0

  tmp=$(mktemp)
  jq --arg theme "$1" '."theme-name" = $theme' "$settings" >"$tmp"
  mv "$tmp" "$settings"

  pgrep -f '^/usr/bin/python3 /usr/bin/ulauncher' >/dev/null || return 0
  pkill -f '^/usr/bin/python3 /usr/bin/ulauncher' || true
  wait_gone -f '^/usr/bin/python3 /usr/bin/ulauncher'
  setsid -f ulauncher --hide-window >/dev/null 2>&1 9>&-
}

nautilus_locations_by_window() {
  busctl --user get-property org.freedesktop.FileManager1 /org/freedesktop/FileManager1 \
    org.freedesktop.FileManager1 OpenWindowsWithLocations --json=short |
    jq -c '.data | map_values(map(select(startswith("x-nautilus-search") | not)) | .[0] // "default")'
}

nautilus_windows_bottom_to_top() {
  local id
  for id in $(xprop -root _NET_CLIENT_LIST_STACKING | grep -o '0x[0-9a-f]*'); do
    [[ "$(xprop -id "$id" WM_CLASS 2>/dev/null)" == *'"org.gnome.Nautilus"'* ]] && echo "$id"
  done
}

window_geometry() {
  xwininfo -id "$1" | awk '/Absolute upper-left X/{x=$NF} /Absolute upper-left Y/{y=$NF}
    /Width:/{w=$NF} /Height:/{h=$NF} END{print x "," y "," w "," h}'
}

window_above() {
  xprop -root _NET_CLIENT_LIST_STACKING | grep -o '0x[0-9a-f]*' | grep -A1 -x "$1" | sed -n 2p
}

place_window() {
  for _ in {1..20}; do
    wmctrl -ir "$1" -e "0,$2"
    sleep 0.1
    [[ "$(window_geometry "$1")" == "$2" ]] && return 0
  done
}

wait_focused() {
  for _ in {1..20}; do
    [[ "$(xprop -root _NET_ACTIVE_WINDOW | grep -o '0x[0-9a-f]*')" == "$1" ]] && return 0
    sleep 0.05
  done
}

wait_new_nautilus_window() {
  local known=$1 id
  for _ in {1..50}; do
    for id in $(nautilus_windows_bottom_to_top); do
      [[ " $known " == *" $id "* ]] && continue
      xwininfo -id "$id" 2>/dev/null | grep -q 'IsViewable' && { echo "$id"; return 0; }
    done
    sleep 0.1
  done
}

# shortcut: only the first tab of each window comes back (Nautilus has no CLI to open tabs) and
# maximized windows come back floating; upgrade if many users run without the GTK4 patch
restart_nautilus() {
  pgrep -x nautilus >/dev/null || return 0

  local active active_was_nautilus=false locations id path windows=()
  active=$(xprop -root _NET_ACTIVE_WINDOW | grep -o '0x[0-9a-f]*')
  locations=$(nautilus_locations_by_window)
  for id in $(nautilus_windows_bottom_to_top); do
    path=$(xprop -id "$id" _GTK_WINDOW_OBJECT_PATH | cut -d'"' -f2)
    windows+=("$(jq -r --arg p "$path" '.[$p] // "default"' <<<"$locations") $(window_geometry "$id") $id $(window_above "$id")")
    [[ "$id" == "$active" ]] && active_was_nautilus=true
  done

  nautilus -q >/dev/null 2>&1 || true
  wait_gone -x nautilus

  local i location geometry old above new opened=""
  local -A reopened
  for ((i = ${#windows[@]} - 1; i >= 0; i--)); do
    read -r location geometry old above <<<"${windows[i]}"
    if [[ "$location" == default ]]; then
      setsid -f nautilus --new-window >/dev/null 2>&1 9>&-
    else
      setsid -f nautilus --new-window "$location" >/dev/null 2>&1 9>&-
    fi
    new=$(wait_new_nautilus_window "$opened")
    [[ -n "$new" ]] || continue
    opened+=" $new"
    reopened[$old]=$new
    wait_focused "$new"
    [[ -n "$above" ]] && "$KIT_DIR/restack-below.py" "$new" "${reopened[$above]:-$above}"
    [[ -n "$active" && ( $active_was_nautilus == false || -n "${reopened[$active]:-}" ) ]] &&
      wmctrl -ia "${reopened[$active]:-$active}"
    place_window "$new" "$geometry"
  done

  [[ -n "$active" && ( $active_was_nautilus == false || -n "${reopened[$active]:-}" ) ]] &&
    restore_focus "${reopened[$active]:-$active}"
}

restore_focus() {
  for _ in {1..10}; do
    sleep 0.2
    [[ "$(xprop -root _NET_ACTIVE_WINDOW | grep -o '0x[0-9a-f]*')" == "$1" ]] && continue
    wmctrl -ia "$1"
  done
}

gtk4_changed=false
if [[ "$(basename "$(readlink "$GTK4_DIR/gtk.css")")" != "gtk-$MODE.css" ]]; then
  ln -sfn "gtk-$MODE.css" "$GTK4_DIR/gtk.css"
  gtk4_changed=true
fi

INTERFACE=org.gnome.desktop.interface
set_if_changed "$INTERFACE" gtk-theme "$THEME"
set_if_changed "$INTERFACE" icon-theme "$ICONS"
set_if_changed "$INTERFACE" color-scheme "$([[ $MODE == Dark ]] && echo prefer-dark || echo default)"
user_theme_schemadir=()
[[ -d $USER_THEME_SCHEMAS ]] && user_theme_schemadir=(--schemadir "$USER_THEME_SCHEMAS")
set_if_changed org.gnome.shell.extensions.user-theme name "$THEME" "${user_theme_schemadir[@]}"
apply_terminal
apply_ulauncher "$1"
BLUR_PIPELINE="'$([[ $MODE == Dark ]] && echo pipeline_default || echo pipeline_default_rounded)'"
dconf write /org/gnome/shell/extensions/blur-my-shell/popup/pipeline "$BLUR_PIPELINE"
dconf write /org/gnome/shell/extensions/blur-my-shell/panel/pipeline "$BLUR_PIPELINE"

SEARCH_LIGHT=/org/gnome/shell/extensions/search-light
if [[ $MODE == Dark ]]; then
  dconf write $SEARCH_LIGHT/text-color '(0.871, 0.871, 0.871, 1.0)'
  dconf write $SEARCH_LIGHT/background-color '(0.141, 0.141, 0.141, 0.5)'
else
  dconf write $SEARCH_LIGHT/text-color '(0.141, 0.141, 0.141, 1.0)'
  dconf write $SEARCH_LIGHT/background-color '(0.961, 0.961, 0.961, 0.5)'
fi

gtk4_reloads_user_css() {
  [[ "$(dpkg-query -W -f='${Version}' libgtk-4-1 2>/dev/null)" == *+livecss* ]]
}

# Ghostty's snap ships its own GTK without live css; SIGUSR2 reloads its config and gtk-custom-css
$gtk4_changed && { pkill -USR2 -x ghostty || true; }

if $gtk4_changed && ! gtk4_reloads_user_css; then
  restart_nautilus
fi
