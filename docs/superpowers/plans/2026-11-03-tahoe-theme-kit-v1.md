# tahoe-theme-kit v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public repo whose `./install.sh <variant>` turns a fresh Ubuntu 24.04 into the MacTahoe setup of `~/.themes` (automatic light/dark switch of the whole desktop).

**Architecture:** `install.sh` sources `lib/common.sh` and runs one function per step from `lib/steps/*.sh`, in order. Variant data lives in `variants/<name>.conf`. The installer writes the machine config to `~/.local/share/tahoe-theme-kit/tahoe.conf` and copies the runtime scripts there. Switchcraft calls `tahoe-mode.sh` from that folder, so the clone can be deleted afterwards. MacTahoe is cloned from upstream at the commits pinned in `upstream.lock`.

**Tech Stack:** bash, python3 (stdlib only), bats 1.10 + shellcheck 0.9 for tests (apt, dev only).

**Spec:** memory note `tahoe-theme-kit-repo` (decisions of 2026-11-03) + the working kit in `~/.themes` (README.md is the source of truth for every step and trap).

## Global Constraints

- Target: Ubuntu 24.04 only (`VERSION_ID="24.04"` in `/etc/os-release`). Anything else → exit 1 with a message. Wayland on 24.04 → warning + confirmation, not an exit.
- Runs as normal user. Refuse to run as root. `sudo -v` once at the start, kept alive in the background; `sudo` only for apt, snap, GDM, Plymouth.
- Only required input: the variant, `amethyst` | `topaz` | `ruby`. Everything else has a default and is asked as a yes/no or a path.
- Each step that uses an image (light wallpaper, dark wallpaper, Plymouth logo) asks whether to change it and the path. Defaults: `wallpaper/MacTahoe-day.jpeg` and `MacTahoe-night.jpeg` from the pinned MacTahoe repo; Plymouth logo `/usr/share/plymouth/ubuntu-logo.png`.
- No personal assets in the repo: no `np_*`, `yellow_*`, NP logo.
- MacTahoe pinned: gtk `1e45e19f510edb8cde18fa84d6cd5319f60b086b`, icons `839848b9a8a38a92a6936e30c4abe35cc6f2546d`. No `git pull` anywhere.
- GTK4 debs: not in git. Uploaded to a GitHub Release (`gtk4-livecss-4.14.5+ds-0ubuntu0.10`); the installer downloads them. `build.sh` stays in the repo.
- Extensions, pinned versions: user-theme (60), blur-my-shell@aunetx (77), rounded-window-corners@fxgn (13), hidetopbar@mathieu.bidon.ca (127), CoverflowAltTab@palatis.blogspot.com (77), compiz-windows-effect@hermes83.github.com (29, optional + patch). **Never** compiz-alike-magic-lamp-effect, burn-my-windows or any other effect extension.
- Switchcraft 1.2.1 from https://github.com/kem-a/switchcraft releases.
- License GPL-3.0 (same as MacTahoe). README and CUSTOMIZING.md in English.
- Commits: no Claude attribution (global rule). Never push until the user says so.
- Code style: no useless comments, early returns, small functions.

## Review Focus

1. **Re-running the installer** on an already set-up machine must not duplicate lines (`.bashrc`, shell CSS, favorites, enabled-extensions) or fail. → idempotency test in Tasks 4, 6, 8.
2. **Image path with spaces, `~`, or a file that is not an image** → `~` expanded, spaces work, non-image re-asks. → Task 3 tests.
3. **user-theme schemas:** `tahoe-mode.sh` hardcodes `--schemadir ~/.local/share/.../user-theme@.../schemas`; if the extension is elsewhere the switch breaks. → Task 2 test with the dir missing.
4. **libgtk-4-1 newer than `4.14.5+ds-0ubuntu0.10`** (fresh install fully updated): the prebuilt debs must not be installed; ask build (≈45 min) or skip. → Task 7 tests.
5. **Variant name typo / missing argument** → usage text listing the variants, exit 2, before any sudo prompt. → Task 1 test.

---

## File Structure

```
install.sh                    entry: args, preflight, runs steps
upstream.lock                 MACTAHOE_GTK_COMMIT=…, MACTAHOE_ICON_COMMIT=…
lib/common.sh                 log, die, ask_yes_no, ask_image, load_variant, render (@VAR@ substitution)
lib/steps/10-preflight.sh     step_preflight
lib/steps/20-packages.sh      step_packages, step_upstream
lib/steps/30-assets.sh        step_assets  (images → tahoe.conf + runtime copy)
lib/steps/40-theme.sh         step_theme, step_icons
lib/steps/50-extensions.sh    step_extensions
lib/steps/60-settings.sh      step_settings, step_switchcraft
lib/steps/70-gtk4.sh          step_gtk4
lib/steps/80-ghostty.sh       step_ghostty
lib/steps/90-boot.sh          step_gdm, step_plymouth, step_nvidia, step_finish
runtime/tahoe-mode.sh         from ~/.themes, reads tahoe.conf next to itself
runtime/restack-below.py      unchanged
variants/{amethyst,topaz,ruby}.conf
shell/tahoe-{light,dark}-shell.css
plymouth/tahoe-logo.plymouth
ghostty/{config,tahoe.css,gen-themes.py}
gtk4-live-css/{build.sh,build-deps.txt,*.patch}
dconf/*.dconf
files/.config/…               copied to ~ (templated: switchcraft/commands.json, user-tmpfiles.d)
optional/60-gsk-renderer.conf
patches/compiz-windows-effect-rwc-shadow.patch
tests/helpers.bash            stub PATH, temp HOME, call log
tests/stubs/                  sudo apt-get snap gsettings dconf curl git gnome-extensions dpkg-query systemctl update-alternatives
tests/*.bats
README.md  CUSTOMIZING.md  LICENSE
```

Runtime layout on the user's machine:
```
~/.local/share/tahoe-theme-kit/{tahoe.conf,tahoe-mode.sh,restack-below.py,backgrounds/,gen-themes.py}
~/.cache/tahoe-theme-kit/{MacTahoe-gtk-theme,MacTahoe-icon-theme,downloads/}
```

**Test approach:** every step is a function; bats tests run it with a temp `HOME` and stubs first on `PATH`. Each stub appends `name args` to `$CALLS` and prints canned output from env vars (e.g. `STUB_DPKG_VERSION`). Assertions check `$CALLS` and files in the temp `HOME`. Real behavior is checked once at the end in a VM (Task 10).

---

### Task 1: Skeleton, common lib, preflight

**Files:**
- Create: `install.sh`, `lib/common.sh`, `lib/steps/10-preflight.sh`, `upstream.lock`, `LICENSE` (GPL-3.0 text, copy `~/.themes/MacTahoe-gtk-theme/COPYING`), `.gitignore`, `tests/helpers.bash`, `tests/stubs/*`, `tests/preflight.bats`, `tests/common.bats`

**Interfaces:**
- Produces: `log MSG`, `die MSG` (exit 1), `ask_yes_no PROMPT DEFAULT(y|n)` → 0/1, reads stdin; `TAHOE_YES=1` answers default. `load_variant NAME` → sources `variants/NAME.conf`, exits 2 with usage if missing. `render SRC DEST` → replaces `@ACCENT@ @ACCENT_HEX@ @ICON_THEME@ @HOME@ @RUNTIME@` with env values. `step_preflight`. Globals: `REPO_DIR`, `RUNTIME=$HOME/.local/share/tahoe-theme-kit`, `CACHE=$HOME/.cache/tahoe-theme-kit`, `OS_RELEASE=${OS_RELEASE:-/etc/os-release}` (overridable for tests).
- `install.sh` order: `step_preflight step_packages step_upstream step_assets step_theme step_icons step_extensions step_settings step_switchcraft step_gtk4 step_ghostty step_gdm step_plymouth step_nvidia step_finish`. Each prints `==> [n/15] name`.

- [ ] **Step 1: tests** — `common.bats`: `render` substitutes all five tokens and leaves other `@x@` alone; `ask_yes_no` with input `\n` returns the default, `n` returns 1, `TAHOE_YES=1` never reads stdin. `preflight.bats`:
  - `./install.sh` with no args and with `rubyy` → exit 2, output contains `amethyst topaz ruby`, `$CALLS` has no `sudo`.
  - `OS_RELEASE` with `VERSION_ID="26.04"` → exit 1, `Ubuntu 24.04`.
  - `XDG_SESSION_TYPE=wayland` + answer `n` → exit 1; answer `y` → continues.
  - `EUID` 0 (run via a `id -u` stub returning 0) → exit 1.
  - success → `sudo -v` called exactly once.
- [ ] **Step 2:** `bats tests/` → FAIL.
- [ ] **Step 3:** implement. Sudo keepalive: `while sudo -n true; do sleep 60; done 2>/dev/null &` with `trap 'kill $!' EXIT`.
- [ ] **Step 4:** `bats tests/ && shellcheck -x install.sh lib/*.sh lib/steps/*.sh` → PASS, no warnings.
- [ ] **Step 5:** commit `feat: installer skeleton and preflight` (include this plan).

### Task 2: Variants and runtime scripts

**Files:**
- Create: `variants/amethyst.conf` (= `~/.themes/tahoe.conf` minus `BG_*`, `PLYMOUTH_LOGO`), `variants/topaz.conf` (from the other PC's `tahoe.conf`, **ask the user to copy it here**; set `ICON_THEME=MacTahoe-yellow`, not `MacTahoe-Yellow-yellow`), `runtime/tahoe-mode.sh`, `runtime/restack-below.py`, `ghostty/gen-themes.py`, `tests/variants.bats`, `tests/tahoe-mode.bats`
- `variants/ruby.conf` is Task 11.

**Interfaces:**
- Variant keys (exact): `ACCENT ACCENT_HEX ICON_THEME TERMINAL_DARK TERMINAL_LIGHT TERMINAL_DARK_PALETTE TERMINAL_LIGHT_PALETTE`.
- `tahoe.conf` = variant + `BG_LIGHT BG_DARK PLYMOUTH_LOGO` as **absolute paths** (was a filename under `backgrounds/`).
- `gen-themes.py CONF` reads the conf path from `argv[1]` (was `../tahoe.conf`).
- `tahoe-mode.sh`: pass `--schemadir` only if that dir exists.

- [ ] **Step 1: tests** — `variants.bats`: every `variants/*.conf` sources cleanly and defines all 7 keys; `ACCENT` ∈ `blue purple pink red orange yellow green grey`; both palettes have 16 `#rrggbb` entries; contrast fg/bg ≥ 4.5 (small python check inside the test). `tahoe-mode.bats` (stubs gsettings, dconf, jq passthrough, dpkg-query returning `+livecss1`): `dark` → `gtk.css` symlink points to `gtk-Dark.css`, gsettings `gtk-theme MacTahoe-Dark-purple`; with the user-theme schemas dir missing, no `--schemadir` in `$CALLS`; bad arg → exit 1. `gen-themes.py` on amethyst writes `tahoe-dark` with `background = #1d1a24`.
- [ ] **Step 2:** run → FAIL. **Step 3:** copy files from `~/.themes`, apply the 3 interface changes. **Step 4:** run → PASS. **Step 5:** commit `feat: variants and runtime scripts`.

### Task 3: Packages, upstream, assets

**Files:**
- Create: `lib/steps/20-packages.sh`, `lib/steps/30-assets.sh`, `tests/assets.bats`, `tests/packages.bats`
- Modify: `lib/common.sh` (add `ask_image`)

**Interfaces:**
- `step_packages`: one `sudo apt-get install -y git sassc libglib2.0-dev-bin jq wmctrl x11-utils imagemagick curl gnome-shell-extension-prefs`.
- `step_upstream`: clone into `$CACHE/MacTahoe-{gtk,icon}-theme` if missing, `git fetch` + `git checkout --detach <commit>` from `upstream.lock`.
- `ask_image PROMPT DEFAULT` → echoes absolute path. Empty answer = default; expands leading `~`; re-asks while `identify` fails.
- `step_assets`: asks 3 images, copies them to `$RUNTIME/backgrounds/` (Plymouth logo too), writes `$RUNTIME/tahoe.conf` (variant + 3 paths, values quoted), copies `runtime/*` and `gen-themes.py` to `$RUNTIME`.

- [ ] **Step 1: tests** — default answers → `tahoe.conf` has `BG_LIGHT="$RUNTIME/backgrounds/MacTahoe-day.jpeg"`; path `~/My Pics/a.png` (with space) is accepted and copied; a text file → prompt repeated, then valid path accepted; `step_upstream` twice → second run makes no `git clone`, checks out the lock commit; re-run of `step_assets` overwrites `tahoe.conf` (no appended duplicates).
- [ ] **Steps 2–4:** fail → implement → pass (+ shellcheck). **Step 5:** commit `feat: packages, upstream checkout, assets`.

### Task 4: Theme, icons, cursors

**Files:**
- Create: `lib/steps/40-theme.sh`, `shell/tahoe-{light,dark}-shell.css`, `tests/theme.bats`

**Interfaces:** `step_theme` = `installTahoe.sh` without `git pull`, run from `$CACHE/MacTahoe-gtk-theme`, shell CSS from `$REPO_DIR/shell`. `step_icons` = `install.sh -t $ACCENT -b` + `cursors/install.sh`, then `gsettings set … cursor-theme MacTahoe-cursors`.

- [ ] **Step 1: tests** (fake MacTahoe `install.sh` stub that creates `~/.themes/MacTahoe-{Light,Dark}-purple/gnome-shell/gnome-shell.css` and `~/.config/gtk-4.0/gtk-{Light,Dark}.css` containing `RGB(0 0 0/15%)`): after `step_theme` the css ends with the overrides with `#7a3f84` substituted, `RGB(…)` became `rgba(0, 0, 0, 0.15)`; running `step_theme` twice leaves exactly one `tahoe-dark-shell overrides` marker.
- [ ] **Steps 2–4**, **Step 5:** commit `feat: theme and icons`.

### Task 5: Extensions

**Files:** Create `lib/steps/50-extensions.sh`, `patches/compiz-windows-effect-rwc-shadow.patch`, `dconf/*.dconf`, `tests/extensions.bats`

**Interfaces:** `EXTENSIONS` array of `uuid:version` (Global Constraints). Download `https://extensions.gnome.org/extension-data/<uuid with @ and . removed>.v<version>.shell-extension.zip` to `$CACHE/downloads`, `gnome-extensions install --force`. Compiz windows effect only if `ask_yes_no "Wobbly windows?" y`; then `patch -N -p0` (skip if `patch --dry-run -R` succeeds, i.e. already applied). Enable by merging uuids into `org.gnome.shell enabled-extensions` (no duplicates) — takes effect at next login. Then `dconf reset -f` + `dconf load` for the 4 dconf files.

- [ ] **Step 1: tests** — `$CALLS` has `curl …blur-myshellaunetx.v77.shell-extension.zip`; with stub `gsettings get` returning `['ubuntu-appindicators@ubuntu.com', 'blur-my-shell@aunetx']` the set value contains each uuid once and keeps appindicators; answer `n` → no compiz download, no patch; no call ever mentions `magic-lamp` or `burn-my-windows`; curl failure → step exits non-zero with the uuid in the message.
- [ ] **Step 1b:** verify the URL format once for real: `curl -sfI https://extensions.gnome.org/extension-data/blur-myshellaunetx.v77.shell-extension.zip` → 200. If it fails, use `/extension-info/?uuid=…&shell_version=46` and record which in the code.
- [ ] **Steps 2–4**, **Step 5:** commit `feat: GNOME extensions`.

### Task 6: Settings and Switchcraft

**Files:** Create `lib/steps/60-settings.sh`, `files/.config/{gtk-3.0/gtk.css,switchcraft/commands.json,user-tmpfiles.d/rustdesk-tray-icon.conf}`, `tests/settings.bats`

**Interfaces:** `step_settings` = README §6 minus the dconf loads (moved to Task 5): wallpapers from `tahoe.conf`, terminal `theme-variant 'system'`, copy `files/` with `render` (commands.json uses `@RUNTIME@/tahoe-mode.sh`, tmpfiles uses `@ICON_THEME@`), `systemctl --user enable systemd-tmpfiles-setup.service`. `step_switchcraft`: skip if `dpkg-query` shows switchcraft installed; else download `switchcraft_1.2.1*.deb` from the release (resolve asset name via `https://api.github.com/repos/kem-a/switchcraft/releases/tags/v1.2.1`), `sudo apt-get install -y ./…deb`. Monitoring toggle stays manual → added to the final checklist (Task 9).

- [ ] **Step 1: tests** — `commands.json` contains `$HOME/.local/share/tahoe-theme-kit/tahoe-mode.sh dark`; tmpfiles points to `MacTahoe-purple`; existing `~/.config/gtk-3.0/gtk.css` with other content is backed up to `gtk.css.bak-tahoe` before overwrite; switchcraft already installed → no curl.
- [ ] **Steps 2–4**, **Step 5:** commit `feat: settings and Switchcraft`.

### Task 7: GTK4 live CSS

**Files:** Create `lib/steps/70-gtk4.sh`, `gtk4-live-css/{build.sh,build-deps.txt,gtk4-user-css-live-reload.patch,gtk4-user-css-live-reload.upstream-4.24.patch}`, `tests/gtk4.bats`

**Interfaces:** `GTK4_BASE=4.14.5+ds-0ubuntu0.10`, `GTK4_RELEASE_URL=https://github.com/<owner>/tahoe-theme-kit/releases/download/gtk4-livecss-$GTK4_BASE` (owner: ask the user at Task 10). Logic on installed `libgtk-4-1` version:
- contains `+livecss` → skip.
- `dpkg --compare-versions "$v" le "$GTK4_BASE"` → download 5 debs, `sudo apt-get install -y ./*.deb`, `sudo apt-mark hold` the 5 packages.
- newer → `ask_yes_no "Build patched GTK4 (~45 min)?" n`; yes → README §8 steps 1–5 automated (deb-src on, build-dep, `build.sh`, install, hold, cleanup, deb-src off); no → log that Nautilus gets restarted on each switch.
- Before installing, warn once: the hold also blocks GTK4 security updates.

- [ ] **Step 1: tests** — 3 branches with `STUB_DPKG_VERSION` = `4.14.5+ds-0ubuntu0.10+livecss1` / `4.14.5+ds-0ubuntu0.10` / `4.14.5+ds-0ubuntu0.11`: skip, install+hold of exactly the 5 names, prompt (answer `n` → no apt call).
- [ ] **Steps 2–4**, **Step 5:** commit `feat: GTK4 live CSS reload`.

### Task 8: Ghostty

**Files:** Create `lib/steps/80-ghostty.sh`, `ghostty/{config,tahoe.css}`, `tests/ghostty.bats`

**Interfaces:** `step_ghostty` = `sudo snap install ghostty --classic` (skip if `snap list ghostty` ok) + body of `setup-ghostty.sh`, with `gen-themes.py "$RUNTIME/tahoe.conf"`. Skip `.bashrc` sed if the line already has `xterm-ghostty`. Set `"theme": "auto"` in `~/.claude/settings.json` only if the file exists (jq merge).

- [ ] **Step 1: tests** — `tahoe.css` has `file://$HOME/.config/gtk-4.0/gtk.css` (no `@HOME@` left); `.bashrc` from Ubuntu's `/etc/skel/.bashrc` gets `xterm-ghostty` once after two runs; favorites `['org.gnome.Terminal.desktop', 'firefox_firefox.desktop']` → Terminal replaced, order kept; no `~/.claude/settings.json` → file not created.
- [ ] **Steps 2–4**, **Step 5:** commit `feat: Ghostty terminal`.

### Task 9: GDM, Plymouth, NVIDIA, finish

**Files:** Create `lib/steps/90-boot.sh`, `plymouth/tahoe-logo.plymouth`, `optional/60-gsk-renderer.conf`, `tests/boot.bats`

**Interfaces:**
- `step_gdm`: `ask_yes_no "Login screen theme?" y` → `install-gdm.sh` body, paths from `$CACHE`/`tahoe.conf`.
- `step_plymouth`: `ask_yes_no "Boot splash?" y` → `install-plymouth.sh` body with `PLYMOUTH_LOGO` from `tahoe.conf`.
- `step_nvidia`: if `lspci | grep -qi nvidia`: if `nvidia-smi` fails → print the README NVIDIA trap (driver not in use) and continue; `ask_yes_no "Use GSK_RENDERER=gl (fixes white button borders on some NVIDIA)?" n` → copy to `~/.config/environment.d/`.
- `step_finish`: run `$RUNTIME/tahoe-mode.sh dark`, then print the checklist: log out and back in; open Switchcraft → Preferences → Monitoring on; the README §12 app list; the §13 verification list.

- [ ] **Step 1: tests** — Plymouth sed gives `ProgressBarForegroundColor=0x7a3f84`; answer `n` to both → no `sudo` call; no NVIDIA → no prompt; NVIDIA + `nvidia-smi` failing → warning text present, exit 0; finish output contains `Monitoring`.
- [ ] **Steps 2–4**, **Step 5:** commit `feat: login, boot splash, NVIDIA, finish`.

### Task 10: Docs, release, VM run

**Files:** Create `README.md`, `CUSTOMIZING.md`, `docs/screenshots/` (user provides images)

- README (English): what it does + screenshots, requirements (24.04, X11 recommended), one-command install, what each step changes and how to undo it (GDM, Plymouth, GTK4 hold), the "Traps" and "Tried and discarded" sections translated from `~/.themes/README.md`, credits (MacTahoe, Switchcraft, gtk4-live-css), GPL-3.0.
- CUSTOMIZING.md: variant keys table, how to add a variant (copy a conf, pick accent from the list, contrast rules 4.5:1 / 3:1, transparency 2–4%), where each step lives, how to rebuild GTK4, how to update the MacTahoe pins (`upstream.lock` + re-test).
- [ ] **Step 1:** ask the user for the GitHub owner; set `GTK4_RELEASE_URL`. Prepare (do not run) `gh release create gtk4-livecss-4.14.5+ds-0ubuntu0.10 ~/.themes/gtk4-live-css/debs/*.deb` — runs only when the user says push.
- [ ] **Step 2:** fresh Ubuntu 24.04 VM (X11 session): `git clone` the local repo, `./install.sh amethyst` with defaults; GTK4 step uses a local file override `GTK4_RELEASE_URL=file://…` until the release exists. Then the §13 checklist. Then run it again: no errors, no duplicates.
- [ ] **Step 3:** `bats tests/ && shellcheck -x install.sh lib/*.sh lib/steps/*.sh` → PASS. Commit `docs: README and CUSTOMIZING`.

### Task 11: Ruby variant

**Files:** Create `variants/ruby.conf`

- `ACCENT=red`; `ACCENT_HEX` readable on light background (≥ 4.5:1 on `#ffffff`); terminal colors designed like amethyst (dark bg tinted red, light bg complementary), 16-color palettes checked with the contrast test from Task 2.
- [ ] **Step 1:** propose 2 palettes to the user as screenshots from the VM; user picks.
- [ ] **Step 2:** `bats tests/variants.bats` → PASS. Commit `feat: ruby variant`.
