# tahoe-theme-kit

Turn a fresh Ubuntu 24.04 into a macOS Tahoe–style desktop where the **Dark Style** button switches *everything* live: GTK and shell theme, icons, wallpaper, libadwaita apps (Nautilus included), the terminal (running sessions too), and the blur. Nothing restarts.

![Dark](docs/screenshots/dark.png)
![Light](docs/screenshots/light.png)

Built on [MacTahoe](https://github.com/vinceliuice/MacTahoe-gtk-theme) by vinceliuice, plus a set of fixes that make it work as a whole.

## Variants

| Variant | Accent |
|---|---|
| `amethyst` | purple |
| `ruby` | red |
| `topaz` | yellow |

To make your own, see [CUSTOMIZING.md](CUSTOMIZING.md).

## Install

Requirements: **Ubuntu 24.04 LTS** (GNOME 46). An **X11** session: pick "Ubuntu on Xorg" on the login screen. On Wayland the installer warns and asks before going on; Nautilus window restore and some extensions may misbehave there.

```sh
git clone https://github.com/nicoptr/tahoe-theme-kit.git
cd tahoe-theme-kit
./install.sh amethyst
```

Run it as your normal user. It asks for your sudo password once. Every other question has a default: press Enter to keep it. You can run it again at any time. It doesn't add anything twice, and it saves your own config files once as `*.bak-tahoe` before replacing them.

When it ends:
1. Log out and back in.
2. Open **Switchcraft → Preferences → Monitoring** and turn it on. From then on the Dark Style button runs the switch.
3. Set your apps to follow the system ([below](#apps)).

## What it does

| Step | What changes | How to undo |
|---|---|---|
| packages | `git sassc libglib2.0-dev-bin jq wmctrl x11-utils imagemagick curl python3-nautilus` | `apt remove` |
| upstream | MacTahoe gtk + icon repos, at pinned commits, in `~/.cache/tahoe-theme-kit` | delete the folder |
| assets | asks for the light wallpaper, the dark wallpaper and the boot logo, then writes `~/.local/share/tahoe-theme-kit/tahoe.conf` | delete the folder |
| theme | MacTahoe GTK + shell theme (`-l -HD --shell -p 45 -h smaller --round`) plus the kit's shell fixes | `MacTahoe-gtk-theme/install.sh -r` |
| icons | MacTahoe icons and cursors | `MacTahoe-icon-theme/install.sh -r` |
| extensions | User Themes, Blur my Shell, Rounded Window Corners Reborn, Hide Top Bar, Dash to Dock (floating, bottom), Coverflow Alt-Tab; optional wobbly windows (Compiz windows effect, patched) | Extension Manager |
| settings | wallpapers, cursor, terminal follows the system, thin terminal scrollbar, Switchcraft commands | GNOME Settings |
| switchcraft | [Switchcraft](https://github.com/kem-a/switchcraft) 1.2.1, which watches the Dark Style button | `apt remove switchcraft` |
| ulauncher | [Ulauncher](https://ulauncher.io) 5.16.2, opens with Ctrl+Super, starts at login | `apt remove ulauncher` |
| gtk4 | patched GTK4 that reloads its CSS live, held with `apt-mark` | see [GTK4](#gtk4) |
| ghostty | [Ghostty](https://ghostty.org) as the default terminal, with a Tahoe title bar and colors from the variant. Nautilus gets "Open in Ghostty" in place of GNOME Terminal's "Open in Terminal" | `snap remove ghostty`, `apt install nautilus-extension-gnome-terminal` |
| gdm | login screen in the dark variant, with your dark wallpaper blurred | `sudo ~/.cache/tahoe-theme-kit/MacTahoe-gtk-theme/tweaks.sh -g -r` |
| plymouth | boot splash with your logo and the accent color on the progress bar | `sudo update-alternatives --set default.plymouth /usr/share/plymouth/themes/bgrt/bgrt.plymouth && sudo update-initramfs -u` |
| nvidia | warns if the NVIDIA driver isn't in use; optional `GSK_RENDERER=gl` | delete `~/.config/environment.d/60-gsk-renderer.conf` |

### How the switch works

```
Dark Style button → gsettings color-scheme changes
                  → Switchcraft notices
                  → ~/.local/share/tahoe-theme-kit/tahoe-mode.sh dark|light
```

`tahoe-mode.sh` switches the GTK and shell theme, the icons, the GTK4 CSS symlink, GNOME Terminal colors, Ulauncher and the Blur my Shell brightness. GNOME switches the wallpaper by itself. Ghostty switches by itself and tells running programs (mode 2031), so Claude Code with `"theme": "auto"` follows too.

### GTK4

Ubuntu's GTK 4.14 reads `~/.config/gtk-4.0/gtk.css` only when an app starts. The [gtk4-live-css](https://github.com/MainstreamOS/gtk4-live-css) patch makes open apps reload it.

- If your `libgtk-4-1` is `4.14.5+ds-0ubuntu0.10` or older, the installer downloads prebuilt packages from this repo's Releases.
- If it's newer, it offers to build them from source (`gtk4-live-css/build.sh`, about 45 minutes).
- If you skip this step, `tahoe-mode.sh` restarts Nautilus on every switch and puts its windows back where they were.

**The packages are held, so GTK4 security updates stop too.** To get them back: `sudo apt-mark unhold libgtk-4-1 libgtk-4-bin libgtk-4-common gir1.2-gtk-4.0 libgtk-4-media-gstreamer && sudo apt upgrade`.

### Apps

| App | Setting |
|---|---|
| JetBrains IDEs | Settings → Appearance → "Sync with OS" |
| Chrome | Appearance → Mode "Device" |
| Sublime Text | `"theme": "auto"`, `"color_scheme": "auto"`, plus `light_color_scheme` and `dark_color_scheme` |
| Claude Code | `"theme": "auto"` (set by the installer if `~/.claude/settings.json` exists) |

These don't follow the system and have to be switched by hand: Brave, Firefox, Telegram, Postman, GIMP.

**Flameshot:** add `X-GNOME-Autostart-Delay=5` after `[Desktop Entry]` in `~/.config/autostart/org.flameshot.Flameshot.desktop`. Without the delay it starts before the tray, falls back to the old xembed tray and shows a color icon.

## Traps we hit

### Theme and shell
- **Brown panel:** came from Blur my Shell at brightness 0.6 in light mode. `tahoe-mode.sh` uses 1.0 in light mode.
- **Crooked corners in quick settings:** the blur used radius 36 and the theme 39. Fixed with `quick-settings-corner-radius=39` (Blur my Shell ≥ 77).
- **Blue accent in quick settings:** came from Blur my Shell's popup style. Fixed with `preserve-shell-theme=true` and `override-background=false`.
- **Calendar and notifications not glassy:** MacTahoe draws them 96% opaque. `shell/tahoe-*-shell.css` fixes that.
- **Missing shadows in libadwaita apps:** MacTahoe writes `RGB(0 0 0/15%)`, which GTK 4.14 drops. The installer rewrites it as `rgba()`.
- **Reload the shell theme without logging out:** write `''` and then the theme name to `/org/gnome/shell/extensions/user-theme/name`.
- **Don't use MacTahoe's `gnome-theme-switcher`:** it deletes `~/.config/gtk-4.0`.
- **Wobbly windows:** without the patch, the Rounded Window Corners shadow stays still and square while the window wobbles. `patches/compiz-windows-effect-rwc-shadow.patch` warps the shadow with the window's own model. It also sets `version` to 9999 in `metadata.json`, so GNOME doesn't auto-update the extension and drop the patch.

### NVIDIA
- **Near-white button borders in GTK4 apps:** the `ngl` renderer draws inset shadows wrong. Seen on an RTX 3070 Ti with driver 580, not on a GT 710 with driver 470. Fixed with `GSK_RENDERER=gl`.
- **The GPU isn't used:** check that `nvidia-smi` works and that Xorg loads `nvidia_drv`, not llvmpipe. The case we saw: the DKMS module wasn't built for the running kernel. The fix was `apt full-upgrade` plus the precompiled `linux-modules-nvidia-<ver>-open-generic`.
- **Boot splash late or low resolution:** NVIDIA KMS is missing at boot (`nvidia-drm.modeset=1`).

### Login screen
- **`$HOME` under `sudo` is `/root`:** the scripts build paths from their own location.
- **Don't pass `-c` to `tweaks.sh -g`:** MacTahoe reads `colors[1]`, which is empty with a single color. So the login screen is always the dark variant.
- **The theme is written but GDM ignores it:** check `update-alternatives --display gdm-theme.gresource`. If it's on "manual" and points at an old custom theme, GDM keeps using that. The installer sets it back to Yaru.
- **A `yaru-theme-gnome-shell` update overwrites the login theme:** run the installer again.

### Terminal
- **Claude Code unreadable after a switch in GNOME Terminal:** GNOME Terminal 3.52 (VTE 0.76) doesn't support mode 2031, so programs never hear about the change. That's why the kit uses Ghostty.
- **No prompt colors in Ghostty:** Ubuntu's `.bashrc` colors the prompt only for `xterm-color` and `*-256color`, and Ghostty uses `xterm-ghostty`. The installer adds it.
- **Transparent Ghostty title bar:** `background-opacity` makes the whole window transparent. `ghostty/tahoe.css` gives the title bar the theme's `@headerbar_bg_color`. Don't use `window-theme = ghostty`, which colors it like the terminal, or `gtk-titlebar-style = tabs`, which makes it transparent again.
- **Ghostty title bar stuck on the startup theme:** the snap ships its own GTK 4.22, without the live CSS patch. So `tahoe.css` imports `~/.config/gtk-4.0/gtk.css`, and Ghostty reloads it on every config reload, including on a theme switch. The import needs an absolute `file://` path, because Ghostty passes the CSS as a string. With the import, MacTahoe's rules get the same priority as ours, so the title bar rule must also beat `headerbar.flat` and `toolbarview > .top-bar headerbar` in specificity.
- **GNOME Terminal changes colors live only with `theme-variant='system'`.**

### Scripts
- **Anchor every `pkill -f` with `^`**, or it kills the shell that runs it.
- **Switchcraft runs commands in the background and keeps no log.** To test: `gsettings set org.gnome.desktop.interface color-scheme default`.
- **The Nautilus restart uses `xprop`, `xwininfo` and `wmctrl`.** `wmctrl -lG` reports wrong coordinates, so it uses `xwininfo`.

## Tried and dropped

- **Nemo instead of Nautilus:** switches live, but looks out of place.
- **libadwaita-without-adwaita:** written for libadwaita 1.10. Ubuntu 24.04 has 1.5.
- **Ubuntu 26.04:** GTK ≥ 4.16 would make the patch unnecessary, but GNOME 50 is Wayland-only, the extensions and the login screen need rework, and the NVIDIA 470 driver (GT 710) is X11-only.

## Development

```sh
sudo apt install bats shellcheck
tests/run.sh
```

The tests run every step against stub commands in `tests/stubs/`. They never call the real `sudo`, apt or gsettings.

## Credits and license

[MacTahoe GTK theme](https://github.com/vinceliuice/MacTahoe-gtk-theme) and [icon theme](https://github.com/vinceliuice/MacTahoe-icon-theme) by vinceliuice, [Switchcraft](https://github.com/kem-a/switchcraft) by kem-a, [gtk4-live-css](https://github.com/MainstreamOS/gtk4-live-css). Default wallpapers are MacTahoe's.

GPL-3.0, see [LICENSE](LICENSE).
