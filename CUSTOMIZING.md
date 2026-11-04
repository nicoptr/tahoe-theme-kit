# Customizing tahoe-theme-kit

This file is for people and coding agents who want to change the kit: add a variant, change a step, or update MacTahoe.

## Layout

| Path | Role |
|---|---|
| `install.sh` | parses the variant, then runs the steps in `STEPS` order |
| `lib/common.sh` | `log`, `warn`, `die`, `ask_yes_no`, `ask_image`, `load_variant`, `render` |
| `lib/steps/NN-*.sh` | one `step_<name>` function per installer step |
| `lib/modules.sh` | `MODULES` (apply order) and `mod_<id>_install`, `mod_<id>_remove`, `mod_<id>_status` per module, built on the steps |
| `lib/engine.sh`, `tahoe-engine` | non-interactive `status` (JSON) and `apply` (`@@start/@@ok/@@fail` lines) used by the app |
| `app/` | the GTK4/libadwaita app (`tahoe_kit.py`), its pure logic (`logic.py`), `modules.json` (titles, notes, previews), `askpass.py` |
| `app/previews/` | preview images, drawn by `make_previews.py` (run it with `env -u GDK_PIXBUF_MODULE_FILE` from Ghostty) |
| `variants/<name>.conf` | variant data (see below) |
| `runtime/` | copied to `~/.local/share/tahoe-theme-kit/`. Switchcraft runs `tahoe-mode.sh` from there, so the clone can be deleted |
| `shell/` | CSS appended to the MacTahoe shell themes. `@ACCENT_HEX@` is replaced |
| `files/` | copied into `~` through `render` (tokens `@ACCENT@ @ACCENT_HEX@ @ICON_THEME@ @HOME@ @RUNTIME@`) |
| `ghostty/` | Ghostty config, title bar CSS, theme generator |
| `dconf/` | extension settings, loaded after a reset |
| `patches/` | Compiz windows effect and Search Light patches |
| `gtk4-live-css/` | GTK4 patch and `build.sh` |
| `upstream.lock` | pinned MacTahoe commits |
| `tests/` | bats tests. `tests/stubs/` stands in for sudo, apt, gsettings and friends |

On the user's machine, `~/.local/share/tahoe-theme-kit/tahoe.conf` is the variant plus `VARIANT`, `BG_LIGHT`, `BG_DARK` and `PLYMOUTH_LOGO` as absolute paths. It is the only state: each module's status is read from the system, so installs from before the app work too.

## Add a module

1. Add its id to `MODULES` in `lib/modules.sh`, where it should run in the apply order.
2. Write `mod_<id>_status` (prints `on`, `off` or `unavailable`), `mod_<id>_install` and `mod_<id>_remove`. Remove puts Ubuntu's default back and restores `*.bak-tahoe` copies with `restore_or_delete`. Never remove base packages.
3. A remove that touches boot, login or every app checks the restore path first and returns `$REFUSED` before changing anything if it is missing, then checks the result and `die`s if it is wrong. The engine rolls a failed module back by running the opposite action.
4. If it reads the variant or the images, add it to `VARIANT_MODULES`.
5. Add its entry to `app/modules.json` (same order) and a preview in `make_previews.py`. `tests/test_app.py` checks that the two lists match.

## Add a variant

1. Copy a variant: `cp variants/amethyst.conf variants/<name>.conf`.
2. Set the keys:

| Key | Value |
|---|---|
| `ACCENT` | a MacTahoe color: `blue purple pink red orange yellow green grey` |
| `ACCENT_HEX` | the accent darkened until it is readable on a light background (≥ 4.5:1 on white). Used in the light shell and the Plymouth progress bar |
| `ICON_THEME` | `MacTahoe-<ACCENT>` |
| `WALLPAPER_HUE` | `(day night)`: hue rotation of MacTahoe's day and night wallpapers for the default wallpapers (ImageMagick `-modulate 100,100,<hue>`; 100 = unchanged, 200 = +180°). The two originals have different hues, so tune them separately |
| `TERMINAL_DARK`, `TERMINAL_LIGHT` | `('bg' 'fg' 'cursor' 'highlight' transparency%)` |
| `TERMINAL_DARK_PALETTE`, `TERMINAL_LIGHT_PALETTE` | 16 colors, as a GVariant string list |

3. Terminal colors:
   - Write explicit colors in both modes, never "theme colors": Ghostty reads them from here.
   - Aim for at least 4.5:1 contrast for the normal colors and 3:1 for the bright ones, also with a dark or light window behind the terminal.
   - Keep transparency at 2–4%.
4. Run `tests/run.sh`. `tests/variants.bats` checks the keys, the palettes and the fg/bg contrast of every variant.
5. Add the variant to the table in `README.md`.

Nothing else needs changing: `install.sh` lists `variants/*.conf` in its usage message.

## Change a step

- Every step is a `step_<name>` function in `lib/steps/`. To add one, put it in the right file and add its name to `STEPS` in `install.sh`.
- Steps must be safe to run again: no duplicate lines, no failure when the work is already done.
- Write the bats test first. Use `load helpers`, then `load_lib`. Assert on the `$CALLS` log written by the stubs and on files in the temporary `$HOME`.
- Stub output and exit codes are set with `STUB_OUT_<NAME>` and `STUB_RC_<NAME>` (e.g. `STUB_OUT_DPKG_QUERY`). For a command that isn't stubbed yet: `ln -s _stub tests/stubs/<name>`.
- Use `run strict step_x` when the behavior depends on `set -e`, as it does in `install.sh`.
- To assert that something did not happen, use `refute grep ...`, not `! grep ...`: bats ignores a failing `!` line unless it is the last one in the test.
- Questions go through `ask_yes_no` and `ask_image`, so `TAHOE_YES=1` answers them all with the default.

## Update MacTahoe

1. In a clone of each MacTahoe repo, check what changed since the commit in `upstream.lock`. Look especially at the `install.sh`/`tweaks.sh` options the kit passes, and at `RGB(` in the GTK4 CSS.
2. Update `upstream.lock`.
3. Run the installer on a test machine or VM, and go through the checklist that `step_finish` prints.

## Rebuild GTK4

When Ubuntu releases a new `gtk4`:

1. Enable `deb-src`, run `sudo apt build-dep gtk4`, then `gtk4-live-css/build.sh` (about 45 minutes). The script checks that the patch made it into the build.
2. Pack the 5 runtime packages: `tar -cf gtk4-livecss-debs.tar -C <build dir> libgtk-4-1_*.deb libgtk-4-bin_*.deb libgtk-4-common_*.deb gir1.2-gtk-4.0_*.deb libgtk-4-media-gstreamer_*.deb`.
3. Publish a Release tagged `gtk4-livecss-<version without "+ds">` with that tar.
4. Update `GTK4_BASE` and `GTK4_RELEASE_URL` in `lib/steps/70-gtk4.sh`.

If the patch stops applying, `gtk4-user-css-live-reload.upstream-4.24.patch` is the upstream version to start from.
