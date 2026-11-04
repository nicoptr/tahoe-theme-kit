# Tahoe Kit app: design

Date: 2026-11-04. Status: draft, waiting for approval.

## Intent

Today the kit is `./install.sh <variant>`: a fixed sequence of steps with a few yes/no prompts in the terminal. It can only add things. Undoing a step means reading the "How to undo" column of the README and doing it by hand.

The app turns the kit into a small control panel. You open it on a fresh Ubuntu to choose what to install, and you open it again later to turn off modules you no longer want. Turning a module off really uninstalls it and puts that part of the system back to Ubuntu's defaults.

It is for anyone who clones the repo from GitHub, not only for the author. Someone who has never read the README should understand what each module does before turning it on.

## Goals

- One window that shows every module, what it looks like, and whether it is on.
- Install, uninstall, and switch between alternatives, such as the launcher.
- Choose the variant, the two wallpapers and the Plymouth logo, with a preview of the chosen image.
- A ready-made preview (image or short animation) for each module, so people can see it before turning it on.
- Changes are collected first and applied together: a summary shows what will be installed and what will be removed, then **Apply**.
- Light: no new dependencies on Ubuntu 24.04 desktop.

## Anti-goals

- **The system must never be left unusable.** This beats every other goal. A failed or half-finished apply must still leave a system that boots, shows the login screen, logs in and has working GTK apps. See [Safety](#safety).
- Not heavy: no Electron, no web server, no runtime that has to be downloaded.
- Not a second copy of the install logic: the CLI and the app run the same module code.

## Non-goals

- Ubuntu 26.04 (separate milestone, as in v1).
- Live preview, meaning applying a change for a few seconds before confirming. Previews are prepared images.
- Bringing back what the user had before the kit. Turning a module off restores **Ubuntu's defaults**: personal tweaks made before the kit are lost. This is a known limit, documented in the README.
- Fixing the wobbly-shadow bug on Wayland (tracked separately).

## Decisions taken with the user

- **Layout B:** a sidebar with the modules on the left, and a detail pane on the right with a large preview, description, controls and notes on what turning it off removes. A bar at the bottom of the window shows "N to install · M to remove" and the **Apply** button.
- Previews are images or short animations stored in the repo. Claude generates them from this PC and the VM. They only need to give the idea, not be pixel-exact.
- The launcher is a single choice: **Search Light**, **Ulauncher**, or **none**. Super+Space opens whichever is chosen.
- Turning off = uninstall and restore Ubuntu's defaults.
- The app also works on a system already set up with the old `install.sh`.

## Decisions made by Claude (open to change)

- **Stack: Python 3 + PyGObject + GTK4 + libadwaita.** On Ubuntu 24.04 desktop these are already installed (`gir1.2-adw-1` is a dependency of `gnome-shell`), so nothing is added. It looks like GNOME Settings, picks up the Tahoe theme by itself, works on X11 and Wayland, and has the native file chooser.
- **The engine stays in bash.** The current `lib/steps/*.sh` become **modules**. Each module has `install`, `remove` and `status`. The CLI and the app call the same module code: the app is a front-end over a non-interactive bash entry point. It never reimplements a step.
- `./install.sh <variant>` keeps working as it does today (all the default modules, prompts in the terminal).
- UI language: English, like the README.
- Launcher: Ulauncher opens through a GNOME custom shortcut that runs `ulauncher-toggle`, because Ulauncher cannot take a global shortcut on Wayland. Its own hotkey is turned off. Whichever launcher is chosen, the keyboard-layout switch moves off Super+Space. When the launcher is "none", the layout switch goes back to Ubuntu's default.
- App entry: `./tahoe-kit` in the repo, plus a `.desktop` file installed for the user so the app shows up in the app grid.

## Modules

Taken from today's steps. Only these change shape:

| Module | Kind | Notes |
|---|---|---|
| variant | choice (amethyst / topaz / ruby) | changes the accent color for the theme, icons, terminal, Plymouth bar |
| images | two wallpapers + Plymouth logo | file chooser + thumbnail; defaults as today |
| theme + icons | on/off | GTK + shell theme, icons, cursors |
| extensions | one sidebar entry per user-visible extension: dock, Blur my Shell, rounded corners, hide top bar, Coverflow Alt-Tab, wobbly | User Themes is not shown; it turns on with the theme |
| launcher | choice: Search Light / Ulauncher / none | |
| switch | on/off | Switchcraft + `tahoe-mode.sh` |
| gtk4 live CSS | on/off | risky, see Safety |
| ghostty | on/off | |
| gdm | on/off | risky |
| plymouth | on/off | risky |
| nvidia fix | on/off | only shown when an NVIDIA card is in use |

Internal steps such as packages, upstream, assets and preflight are not modules shown to the user. They run as dependencies of the modules that need them.

## State

`~/.local/share/tahoe-theme-kit/state.json` records the variant, the image paths, which modules are on, and **which apt packages, snaps and debs the kit installed itself**. Uninstall removes only what the kit added. A package that was already on the system before the kit is never removed.

On a system set up with the old `install.sh` there is no state file. Each module's `status` detects what is installed from the system itself (extension folder present, package installed, GDM theme in use, and so on).

## Safety

The anti-goal is turned into rules:

1. **Plan before apply.** The summary lists every package, file and system setting that will change. Nothing runs until **Apply**.
2. **Modules that touch boot, login or every GTK app** (gtk4, gdm, plymouth, nvidia env) get extra care:
   - Before removing, check that the restore path exists: for gtk4, that the stock `libgtk-4-1` version is downloadable from the archive before the patched one is unheld and replaced; for plymouth, that the `bgrt` theme is present.
   - After installing or removing, check the result: GDM theme file in place, `update-initramfs` exit code, the GTK4 package version.
   - If the check fails, put back the previous state of that module and stop.
3. **Stop at the first failure.** Modules already applied stay applied. The failed module is rolled back to how it was before. The app shows the log and which module failed. Every `install` and `remove` must be safe to run again on a half-done module.
4. **Order:** apply removals of risky modules before installs of others. Never remove the active shell or GTK theme: switch to Yaru first.
5. **sudo:** the app asks for the password once, in its own dialog. The password is never written to disk or into logs.
6. **VM acceptance test** before merge (24.04, X11 and Wayland): install everything → remove everything → reboot. The result must be Ubuntu's defaults, the login works, GTK apps open. Then install everything again.

## Previews

`previews/<module>.png` or `.webp` (animated where motion matters: wobbly, dock, launcher). Variant swatches are generated from `variants/*.conf`. Claude makes the previews from this PC and the VM. Rough is fine.

## Left to the builder

- How exactly the app keeps sudo for the whole apply without a terminal (for example `sudo -S` with the password from the dialog, or `pkexec` for a root-only helper), within rule 5.
- The JSON shape of `state.json` and of the bash ↔ app protocol (progress, log lines, errors).
- How each extension's "restore defaults" works (`dconf reset -f` of its path plus `gnome-extensions uninstall`).
- Tests: the bats suite covers the module scripts. The app needs at least a smoke test that builds the window without showing it.

## Answers to the review (Claude's calls, made while the user was away; to be checked)

1. **Packages.** The modules that are apps own their own packages and remove them when turned off: Switchcraft, Ulauncher and the Ghostty snap. On old installs too, because they are clearly the kit's. The shared base packages (`git sassc jq curl imagemagick …`) are **never removed**. They are harmless, other software may rely on them, and removing them is the kind of surprise the anti-goal is about. Turning Ghostty off reinstalls `nautilus-extension-gnome-terminal` (Ubuntu ships it). The kit's own folders (`~/.cache/tahoe-theme-kit`, `~/.local/share/tahoe-theme-kit`) stay. They are small, and the app needs them to turn modules back on.
2. **Branch.** Work starts from `feat/search-light` (Search Light is part of the launcher module), on `feat/app`.
3. **Files from `settings`.** Each file goes to the module that needs it: `gtk-3.0/gtk.css` → theme, `switchcraft/commands.json` → switch, `ulauncher/*` + autostart → launcher (Ulauncher), `rustdesk-tray-icon.conf` → icons. Wallpapers and terminal-follows-system → their own **wallpaper** module. Turning a module off **restores `*.bak-tahoe` when it exists**, otherwise deletes the file. The kit's lines in `~/.bashrc` are reverted. `~/.claude/settings.json` `theme: auto` is left alone, because it is harmless.
4. **Dependencies.** The switch needs the theme. User Themes goes with the theme. GDM and Plymouth need only the images. Everything else is independent. Turning the theme off also turns the switch off, and the summary says so before Apply. `tahoe-mode.sh` already tolerates missing extensions (writes to dconf only).
5. **Wayland.** Supported. The preflight no longer asks: it only informs. Wobbly windows carries a note: on Wayland the shadow can stay behind as a square (known bug, not fixed here).
6. **GTK4 build from source.** Not offered in the app. The gtk4 module shows "not available for your GTK version" and points to `./install.sh`, which keeps the 45-minute build.
