# Tahoe Kit App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A GTK4/libadwaita control panel that installs, removes and switches the kit's modules, on top of a bash engine shared with `./install.sh`.

**Architecture:** The existing `step_*` functions stay as they are (the CLI and its tests keep working). `lib/modules.sh` adds per-module `mod_<id>_install`, `mod_<id>_remove` and `mod_<id>_status` built on those steps. `./tahoe-engine` is the non-interactive entry point: `status` prints JSON, and `apply` takes the wanted state and prints `@@` progress lines. `app/tahoe_kit.py` is a front-end that only calls the engine.

**Tech Stack:** bash + bats + shellcheck (existing), Python 3.12 + PyGObject + GTK 4.14 + libadwaita 1.5 (preinstalled on Ubuntu 24.04 desktop).

**Spec:** `docs/superpowers/specs/2026-11-04-tahoe-kit-app-design.md`

## Global Constraints

- Ubuntu 24.04 only. No new apt dependencies for the app.
- The engine must never be left half-way on a risky module: gtk4, gdm and plymouth check the restore path before removing, and check the result after.
- The engine stops at the first failing module and rolls that module back.
- The sudo password is never written to disk, into logs or into argv.
- Base packages (`PACKAGES` in `20-packages.sh`) are never removed.
- Turning a module off restores `*.bak-tahoe` when it exists, otherwise deletes the kit's file.
- Turning the theme off also turns the switch off.
- Launcher choices: `searchlight`, `ulauncher`, `none`. Both launchers open with `<Super>space`.
- UI text in English.

## Module ids

`theme`, `wallpaper`, `dock`, `blur`, `corners`, `hidetopbar`, `coverflow`, `wobbly`, `launcher` (choice), `switch`, `gtk4`, `ghostty`, `gdm`, `plymouth`, `nvidia`. `status` prints one of `on`, `off`, `unavailable`, or for `launcher` the choice.

## Review Focus

1. Removing the theme while it is the active GTK/shell theme: GNOME must fall back to Yaru, not to a missing theme (test: `mod_theme_remove` resets `gtk-theme`, `icon-theme`, `cursor-theme` and the user-theme `name` before deleting).
2. gtk4 off when the stock version is no longer in the archive: must stop without unholding (test: `apt-cache madison` stub with no stock version → error, no `apt-mark unhold`).
3. A user file replaced by the kit: turning the module off restores the `.bak-tahoe` copy, never deletes the user's original (test in Task 2).
4. Apply where one module fails in the middle: later modules don't run, and the output names the failed module (test in Task 1).
5. A system set up with the old `install.sh` (no `state.json`): `status` must still report the right modules as on (test: status from the extension folders and the dpkg stub, without state).

---

### Task 1: Engine and module framework

**Files:**
- Create: `lib/modules.sh`, `tahoe-engine`, `tests/engine.bats`
- Modify: `lib/common.sh` (sudo wrapper), `tests/run.sh` (shellcheck the new files)

**Interfaces:**
- Produces: `MODULES` (ordered array of ids, the apply order), `module_requires <id>` (prints ids), `mod_<id>_{install,remove,status}`, `restore_or_delete <dest>`, `state_get <key>` / `state_set <key> <value>` on `$RUNTIME/state.json` (jq).
- Engine CLI: `tahoe-engine status` → `{"variant": str|null, "bg_light": str|null, "bg_dark": str|null, "logo": str|null, "session": "x11"|"wayland", "modules": {id: state}}`. `tahoe-engine apply [--variant V] [--bg-light P] [--bg-dark P] [--logo P] id=on|off|<choice> ...` → stdout lines `@@start <id> <install|remove>`, `@@ok <id>`, `@@fail <id>`, everything else is log; exit 1 on failure.
- `sudo()` in common.sh: when `SUDO_ASKPASS` is set it runs `command sudo -A "$@"`, otherwise `command sudo "$@"`.

- [ ] Tests: `status prints JSON with every module`, `apply runs install for on and remove for off in MODULES order`, `apply stops at the first failing module and prints @@fail`, `theme off implies switch off`, `sudo uses -A when SUDO_ASKPASS is set`.
- [ ] Implement, run `tests/run.sh`, commit.

### Task 2: Low-risk modules (install + remove + status)

**Files:** Modify `lib/modules.sh`, `lib/steps/50-extensions.sh` (split `step_extensions` into `install_extension_entry <uuid>` + the existing loop), `lib/steps/60-settings.sh` (file ownership per module). Create `tests/modules.bats`.

- theme: install = upstream + assets + `step_theme` + `step_icons` + user-theme + `gtk-3.0/gtk.css` + rustdesk tmpfiles. Remove = reset `org.gnome.desktop.interface` `gtk-theme icon-theme cursor-theme color-scheme`, reset user-theme `name`, disable + uninstall user-theme, MacTahoe `install.sh -r`, icon theme `install.sh -r`, `rm -rf ~/.icons/MacTahoe-cursors`, restore_or_delete owned files, `rm ~/.config/gtk-4.0/gtk.css` symlink + `gtk-{Light,Dark}.css`.
- wallpaper: install = gsettings picture-uri(-dark) + terminal theme-variant. Remove = `gsettings reset` of both + `dconf reset` theme-variant.
- extension modules: install = download + install + patch (wobbly: compiz patch; launcher searchlight: blur patch) + enable + dconf load. Remove = drop from `enabled-extensions`, `gnome-extensions uninstall`, `dconf reset -f` its path. dock maps to `dash-to-dock@micxgx.gmail.com` + `dash-to-dock` path; blur also owns `appindicator` settings.
- launcher: searchlight = extension + dconf + `<Super>space`; ulauncher = deb + settings + autostart + custom keybinding `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/tahoe-launcher/` running `ulauncher-toggle` on `<Super>space`, `hotkey-show-app` empty; none = remove both, reset `switch-input-source(-backward)`.
- switch: Switchcraft deb + `commands.json`; remove = `apt-get remove -y switchcraft` + restore_or_delete.
- ghostty: remove = reset favorites (ghostty → `org.gnome.Terminal.desktop`), reset `default-applications.terminal`, `apt-get install -y nautilus-extension-gnome-terminal`, delete nautilus-python ext + local desktop file, restore_or_delete ghostty config, revert the `.bashrc` sed, `snap remove ghostty`.
- nvidia: file in `environment.d`.
- [ ] Tests per module: install calls, remove calls (Review Focus 1 and 3), status on/off. Implement, run, commit.

### Task 3: Risky modules

**Files:** Modify `lib/modules.sh`. Tests in `tests/modules.bats`.

- gtk4 remove: stock version = highest `apt-cache madison libgtk-4-1` without `livecss`. None → fail before any change (Review Focus 2). Else `apt-mark unhold`, `apt-get install -y --allow-downgrades pkg=ver…`, check `dpkg-query` has no `+livecss`. Status `unavailable` when the installed version is newer than `GTK4_BASE` and not patched.
- gdm remove: `tweaks.sh -g -r`, then `update-alternatives --set gdm-theme.gresource $YARU_GRESOURCE`, check `update-alternatives --query` shows Yaru.
- plymouth remove: check bgrt exists, `--set` bgrt, `--remove` tahoe-logo, `rm -rf` theme dir, `update-initramfs -u` (failure → set tahoe-logo back, fail).
- [ ] Tests, implement, run, commit.

### Task 4: install.sh on top of the modules + Wayland preflight

`install.sh` keeps its prompts and the 16-step output (existing test). Preflight on Wayland: `log` a note, no question. README: module table, app section, known limit (Ubuntu defaults, not the user's earlier tweaks), Wayland supported.
- [ ] Update `preflight.bats`, run, commit.

### Task 5: The app

**Files:** Create `app/tahoe_kit.py`, `app/modules.json` (id, title, description, kind, choices, preview, risky, wayland_note), `app/askpass.py`, `tahoe-kit` (launcher script), `tests/test_app.py`. Modify `tests/run.sh` (python tests + `python3 -m py_compile`).

- Layout B: `Adw.NavigationSplitView`. Sidebar: Variant, Images, then the modules. Content: a preview `Gtk.Picture` (animated WebP/GIF via `Gtk.MediaFile` when animated), description, a `Adw.SwitchRow` or `Adw.ComboRow`, and notes ("Turning this off also turns off: …", risky warning, Wayland note). Images page: three rows with a thumbnail and `Gtk.FileDialog`.
- Bottom bar: "N to install · M to remove" + **Apply**. Apply opens a dialog with the plan, then a password `Adw.PasswordEntryRow`, then runs `tahoe-engine apply` with `SUDO_ASKPASS=app/askpass.py` and `TAHOE_ASKPASS_SOCK` (a 0600 unix socket in `$XDG_RUNTIME_DIR` served by the app from memory), showing log lines and the `@@` progress.
- Pure logic in testable functions: `plan(current: dict, wanted: dict) -> list[tuple[str, str]]`, `apply_args(wanted) -> list[str]`, `parse_progress(line) -> tuple|None`.
- [ ] Tests: plan with theme off adds switch off; apply_args; parse_progress; building the window headless (`GDK_BACKEND=broadway`-free: construct widgets without `present()`).
- [ ] Desktop file installed by `mod_theme_install`? No: by `./tahoe-kit --install-desktop-file` and by `install.sh`'s finish step.
- [ ] Run, commit.

### Task 6: Previews

`app/previews/<id>.(png|webp)`: screenshots from this PC (X11) with `import -window root`, cropped. Animated ones (wobbly, dock, launcher) as short WebP made from frames. Variant swatches drawn from `variants/*.conf`. Rough is fine (spec).
- [ ] Generate, check the app shows them, commit.
