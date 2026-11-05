#!/usr/bin/env python3
"""Tahoe Kit: turn the kit's modules on and off. Every change goes through ../tahoe-engine."""

import json
import os
import socket
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, Gtk  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import logic  # noqa: E402

APP_ID = "io.github.nicoptr.TahoeKit"
ASKPASS = os.path.join(logic.REPO_DIR, "app", "askpass.py")
IMAGES = [("bg_light", "Light wallpaper"), ("bg_dark", "Dark wallpaper (also the login screen)"),
          ("logo", "Boot splash logo (PNG, light on transparent)")]
RECOMMENDED_OFF = {"nvidia"}
CSS = b"""
.preview { border-radius: 12px; }
.pending { color: @accent_color; font-weight: bold; }
"""


class AskpassServer:
    """Hands sudo the password from memory, over a socket only this user can open."""

    def __init__(self, password):
        self.password = password
        self.path = os.path.join(GLib.get_user_runtime_dir(), f"tahoe-kit-{os.getpid()}.sock")
        if os.path.exists(self.path):
            os.unlink(self.path)
        self.sock = socket.socket(socket.AF_UNIX)
        old = os.umask(0o177)
        try:
            self.sock.bind(self.path)
        finally:
            os.umask(old)
        self.sock.listen()
        threading.Thread(target=self._serve, daemon=True).start()

    def _serve(self):
        while True:
            try:
                conn, _ = self.sock.accept()
            except OSError:
                return
            with conn:
                conn.sendall((self.password + "\n").encode())

    def close(self):
        self.sock.close()
        if os.path.exists(self.path):
            os.unlink(self.path)


def engine_status():
    out = subprocess.run([logic.ENGINE, "status"], capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def sudo_password_ok(password):
    r = subprocess.run(["sudo", "-S", "-k", "-v", "-p", ""], input=password + "\n", capture_output=True, text=True)
    return r.returncode == 0


def preview_widget(frames, height=280):
    picture = Gtk.Picture(content_fit=Gtk.ContentFit.CONTAIN, height_request=height)
    picture.add_css_class("preview")
    picture.set_overflow(Gtk.Overflow.HIDDEN)
    paths = [os.path.join(logic.PREVIEWS, f) for f in frames]
    picture.set_filename(paths[0])
    if len(paths) > 1:
        state = {"i": 0}

        def step():
            if not picture.get_root():
                return GLib.SOURCE_CONTINUE
            state["i"] = (state["i"] + 1) % len(paths)
            picture.set_filename(paths[state["i"]])
            return GLib.SOURCE_CONTINUE

        GLib.timeout_add(450, step)
    return picture


def page_box(*children):
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18, margin_top=24, margin_bottom=24,
                  margin_start=12, margin_end=12)
    for c in children:
        box.append(c)
    clamp = Adw.Clamp(maximum_size=720, child=box)
    return Gtk.ScrolledWindow(child=clamp, vexpand=True)


def note(text, css="dim-label"):
    label = Gtk.Label(label=text, wrap=True, xalign=0)
    label.add_css_class(css)
    return label


class KitWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Tahoe Kit", default_width=980, default_height=720)
        self.meta = {m["id"]: m for m in logic.load_modules()}
        self.variants = logic.load_variants()
        self.running = False
        self.syncing = False
        self.controls = {}
        self.suffixes = {}
        self.images = {}
        self.notes = {}
        self.connect("close-request", lambda *_: self.running)
        self._load_status()
        self._build()
        self._refresh()

    def _load_status(self):
        self.status = engine_status()
        self.current = self.status["modules"]
        self.wanted = dict(self.current)
        self.variant = self.wanted_variant = self.status["variant"]

    # ---------- layout ----------

    def _build(self):
        self.toasts = Adw.ToastOverlay()
        self.stack = Gtk.Stack()
        self.sidebar = Gtk.ListBox(selection_mode=Gtk.SelectionMode.SINGLE)
        self.sidebar.add_css_class("navigation-sidebar")
        self.sidebar.connect("row-selected", self._on_row_selected)

        self._add_page("variant", "Variant", self._variant_page())
        self._add_page("images", "Images", self._images_page())
        for module_id in self.meta:
            self._add_page(module_id, self.meta[module_id]["title"], self._module_page(self.meta[module_id]))

        sidebar_view = Adw.ToolbarView(content=Gtk.ScrolledWindow(child=self.sidebar, vexpand=True))
        sidebar_view.add_top_bar(Adw.HeaderBar(show_title=False))
        self.content_title = Adw.WindowTitle(title="Variant")
        content_view = Adw.ToolbarView(content=self.stack)
        content_view.add_top_bar(Adw.HeaderBar(title_widget=self.content_title))

        self.split = Adw.NavigationSplitView(
            sidebar=Adw.NavigationPage(title="Tahoe Kit", child=sidebar_view),
            content=Adw.NavigationPage(title="Variant", child=content_view),
            min_sidebar_width=230)

        self.summary = Gtk.Label(xalign=0, hexpand=True)
        self.apply_button = Gtk.Button(label="Apply")
        self.apply_button.add_css_class("suggested-action")
        self.apply_button.connect("clicked", self._on_apply)
        bar = Gtk.ActionBar()
        bar.pack_start(self.summary)
        bar.pack_end(self.apply_button)

        self.banner = Adw.Banner(title="Nothing from the kit is installed yet.", button_label="Select the recommended set")
        self.banner.connect("button-clicked", self._select_recommended)

        outer = Adw.ToolbarView(content=self.split)
        outer.add_top_bar(self.banner)
        outer.add_bottom_bar(bar)
        self.toasts.set_child(outer)
        self.set_content(self.toasts)
        self.sidebar.select_row(self.sidebar.get_row_at_index(0))

    def _add_page(self, key, title, widget):
        row = Adw.ActionRow(title=title)
        row.page_key = key
        suffix = Gtk.Label()
        row.add_suffix(suffix)
        self.suffixes[key] = suffix
        self.sidebar.append(row)
        self.stack.add_titled(widget, key, title)

    def _on_row_selected(self, _box, row):
        if row is None:
            return
        self.stack.set_visible_child_name(row.page_key)
        self.content_title.set_title(row.get_title())
        self.split.set_show_content(True)

    def _variant_page(self):
        self.variant_preview = Gtk.Picture(content_fit=Gtk.ContentFit.CONTAIN, height_request=200)
        self.variant_preview.add_css_class("preview")
        group = Adw.PreferencesGroup(title="Variant", description="The accent color used by the theme, icons, terminal and boot splash.")
        first = None
        self.variant_buttons = {}
        for v in self.variants:
            check = Gtk.CheckButton(group=first)
            first = first or check
            check.connect("toggled", self._on_variant, v["name"])
            row = Adw.ActionRow(title=v["name"].capitalize(), subtitle=v["accent_hex"], activatable_widget=check)
            row.add_prefix(check)
            group.add(row)
            self.variant_buttons[v["name"]] = check
        return page_box(self.variant_preview, group)

    def _images_page(self):
        group = Adw.PreferencesGroup(title="Images", description="Pick your own, or keep the kit's: recolored MacTahoe wallpapers and Ubuntu's logo.")
        self.thumbs = {}
        self.image_preview = Gtk.Picture(content_fit=Gtk.ContentFit.CONTAIN, height_request=240)
        self.image_preview.add_css_class("preview")
        for key, title in IMAGES:
            thumb = Gtk.Picture(content_fit=Gtk.ContentFit.COVER, width_request=96, height_request=60)
            thumb.add_css_class("preview")
            thumb.set_overflow(Gtk.Overflow.HIDDEN)
            path = self.status.get(key)
            if path and os.path.isfile(path):
                thumb.set_filename(path)
            self.thumbs[key] = thumb
            button = Gtk.Button(label="Choose…", valign=Gtk.Align.CENTER)
            button.connect("clicked", self._choose_image, key, title)
            row = Adw.ActionRow(title=title, subtitle=path or "the kit's default")
            row.add_prefix(thumb)
            row.add_suffix(button)
            row.image_key = key
            group.add(row)
            self.thumbs[key + "_row"] = row
        current = self.status.get("bg_dark")
        if current and os.path.isfile(current):
            self.image_preview.set_filename(current)
        return page_box(self.image_preview, group,
                        note("New images are applied to the wallpapers, the login screen and the boot splash that are on."))

    def _choose_image(self, _button, key, title):
        dialog = Gtk.FileDialog(title=title)
        images = Gtk.FileFilter(name="Images")
        images.add_mime_type("image/*")
        filters = Gio.ListStore.new(Gtk.FileFilter)
        filters.append(images)
        dialog.set_filters(filters)

        def done(d, result):
            try:
                path = d.open_finish(result).get_path()
            except GLib.Error:
                return
            self.images[key] = path
            self.thumbs[key].set_filename(path)
            self.thumbs[key + "_row"].set_subtitle(path)
            self.image_preview.set_filename(path)
            self._refresh()

        dialog.open(self, None, done)

    def _module_page(self, m):
        group = Adw.PreferencesGroup(title=m["title"], description=m["description"])
        if m["kind"] == "choice":
            labels = Gtk.StringList.new([label for _, label in m["choices"]])
            row = Adw.ComboRow(title="Use", model=labels)
            row.connect("notify::selected", self._on_choice, m)
        else:
            row = Adw.SwitchRow(title="Installed")
            row.connect("notify::active", self._on_toggle, m["id"])
        self.controls[m["id"]] = row
        group.add(row)
        self.notes[m["id"]] = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        return page_box(preview_widget(m["preview"]), group, self.notes[m["id"]])

    def _fill_notes(self, m):
        box = self.notes[m["id"]]
        while child := box.get_first_child():
            box.remove(child)
        state = self.current.get(m["id"])
        if state == "unavailable":
            box.append(note(m.get("unavailable_note", "Not available on this computer."), "warning"))
            return
        if m.get("requires"):
            names = ", ".join(self.meta[r]["title"] for r in m["requires"] if self.current.get(r) != "unavailable")
            box.append(note(f"Needs: {names}. Turning that off turns this off too."))
        if m.get("risky"):
            box.append(note("This one changes system files. The kit checks the result and puts things back if a step fails.", "warning"))
        if m.get("wayland_note") and self.status.get("session") == "wayland":
            box.append(note(m["wayland_note"], "warning"))
        if m.get("off_note"):
            box.append(note("Turning it off: " + m["off_note"]))

    # ---------- state ----------

    def _on_variant(self, check, name):
        if check.get_active() and not self.syncing:
            self.wanted_variant = name
            self._refresh()

    def _on_toggle(self, row, _pspec, module_id):
        if self.syncing:
            return
        self.wanted[module_id] = "on" if row.get_active() else "off"
        for other, m in self.meta.items():
            if module_id in m.get("requires", []) and self.wanted[module_id] == "off":
                self.wanted[other] = "off"
            if other == module_id and self.wanted[module_id] == "on":
                for r in m.get("requires", []):
                    if self.current.get(r) != "unavailable":
                        self.wanted[r] = "on"
        self._refresh()

    def _on_choice(self, row, _pspec, m):
        if not self.syncing:
            self.wanted[m["id"]] = m["choices"][row.get_selected()][0]
            self._refresh()

    def _select_recommended(self, *_):
        for module_id, m in self.meta.items():
            if self.current.get(module_id) == "unavailable":
                continue
            if m["kind"] == "choice":
                self.wanted[module_id] = m["choices"][0][0]
            else:
                self.wanted[module_id] = "off" if module_id in RECOMMENDED_OFF else "on"
        self.wanted_variant = self.wanted_variant or self.variants[0]["name"]
        self._refresh()

    def _state_label(self, module_id, value):
        m = self.meta[module_id]
        if m["kind"] == "choice":
            return dict(m["choices"]).get(value, value)
        return {"on": "On", "off": "Off", "unavailable": "N/A"}.get(value, value)

    def _refresh(self):
        self.syncing = True
        for module_id, row in self.controls.items():
            m, value = self.meta[module_id], self.wanted.get(module_id, "off")
            if m["kind"] == "choice":
                ids = [c for c, _ in m["choices"]]
                row.set_selected(ids.index(value) if value in ids else len(ids) - 1)
            else:
                row.set_active(value == "on")
                row.set_sensitive(self.current.get(module_id) != "unavailable" and not self.running)
            pending = logic.with_implied(self.wanted).get(module_id) != self.current.get(module_id) \
                and self.current.get(module_id) != "unavailable"
            suffix = self.suffixes[module_id]
            suffix.set_label(("• " if pending else "") + self._state_label(module_id, value))
            suffix.set_css_classes(["pending"] if pending else ["dim-label"])
            self._fill_notes(m)
        for name, check in self.variant_buttons.items():
            check.set_active(name == self.wanted_variant)
        shown = self.wanted_variant or self.variants[0]["name"]
        self.variant_preview.set_filename(os.path.join(logic.PREVIEWS, f"variant-{shown}.png"))
        variant_pending = self.wanted_variant != self.variant
        self.suffixes["variant"].set_label(("• " if variant_pending else "") + (self.wanted_variant or "choose").capitalize())
        self.suffixes["variant"].set_css_classes(["pending"] if variant_pending else ["dim-label"])
        self.suffixes["images"].set_label(f"• {len(self.images)} new" if self.images else "")
        self.suffixes["images"].set_css_classes(["pending"])
        self.syncing = False

        steps = logic.plan(self.current, self.wanted)
        installs = sum(1 for _, a in steps if a != "remove")
        removes = sum(1 for _, a in steps if a == "remove")
        parts = []
        if installs:
            parts.append(f"{installs} to install")
        if removes:
            parts.append(f"{removes} to remove")
        if variant_pending and self.variant:
            parts.append("new variant")
        if self.images:
            parts.append("new images")
        self.summary.set_label(" · ".join(parts) or "No changes")
        self.apply_button.set_sensitive(bool(parts) and not self.running)
        nothing = all(v in ("off", "none", "unavailable") for v in self.current.values())
        self.banner.set_revealed(nothing and not steps)

    # ---------- apply ----------

    def _plan_lines(self):
        lines = []
        for module_id, action in sorted(logic.plan(self.current, self.wanted), key=lambda s: s[1] == "remove"):
            title = self.meta[module_id]["title"]
            if action == "install":
                lines.append(f"Install: {title}")
            elif action == "remove":
                lines.append(f"Remove: {title}")
            else:
                lines.append(f"{title}: {self._state_label(module_id, action)}")
        if self.wanted_variant != self.variant and self.variant:
            lines.append(f"Variant: {self.wanted_variant}")
        lines += [f"New image: {dict(IMAGES)[k]}" for k in self.images]
        return lines

    def _on_apply(self, _button):
        steps = logic.plan(self.current, self.wanted)
        needs_variant = any(a != "remove" for _, a in steps) or self.images
        if needs_variant and not self.wanted_variant:
            self.toasts.add_toast(Adw.Toast(title="Choose a variant first"))
            self.sidebar.select_row(self.sidebar.get_row_at_index(0))
            return
        dialog = Adw.AlertDialog(heading="Apply these changes?", body="\n".join(self._plan_lines()))
        password = Gtk.PasswordEntry(show_peek_icon=True, placeholder_text="Your password, for sudo")
        dialog.set_extra_child(password)
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("apply", "Apply")
        dialog.set_response_appearance("apply", Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response("apply")

        def on_enter(_entry):
            dialog.close()
            self._check_password_and_run(password.get_text())

        password.connect("activate", on_enter)

        def on_response(_d, response):
            if response == "apply":
                self._check_password_and_run(password.get_text())

        dialog.connect("response", on_response)
        dialog.present(self)

    def _check_password_and_run(self, password):
        self.running = True
        self._refresh()

        def check():
            ok = sudo_password_ok(password)
            GLib.idle_add(self._run_engine if ok else self._wrong_password, password)

        threading.Thread(target=check, daemon=True).start()

    def _wrong_password(self, _password):
        self.running = False
        self._refresh()
        self.toasts.add_toast(Adw.Toast(title="Wrong password, or this user can't use sudo"))

    def _run_engine(self, password):
        args = logic.apply_args(self.current, self.wanted, self.wanted_variant, self.images)
        planned = [m for m, _ in logic.plan(self.current, self.wanted)]
        self.askpass = AskpassServer(password)

        win = Adw.Window(transient_for=self, modal=True, default_width=720, default_height=520, title="Applying")
        win.connect("close-request", lambda *_: self.running)
        self.progress_label = Gtk.Label(label="Starting…", xalign=0)
        self.progress = Gtk.ProgressBar()
        self.progress_total = max(len(planned) + 1, 1)
        self.progress_done = 0
        self.log = Gtk.TextView(editable=False, monospace=True, wrap_mode=Gtk.WrapMode.WORD_CHAR)
        log_scroll = Gtk.ScrolledWindow(child=self.log, vexpand=True)
        self.close_button = Gtk.Button(label="Close", sensitive=False, halign=Gtk.Align.END)
        self.close_button.connect("clicked", lambda *_: win.destroy())
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin_top=12, margin_bottom=12,
                      margin_start=12, margin_end=12)
        for w in (self.progress_label, self.progress, log_scroll, self.close_button):
            box.append(w)
        view = Adw.ToolbarView(content=box)
        view.add_top_bar(Adw.HeaderBar())
        win.set_content(view)
        win.present()
        self.events = []

        # the engine writes to a file, not to a pipe of ours: if the app dies, the engine doesn't
        os.makedirs(os.path.dirname(logic.APPLY_LOG), exist_ok=True)
        open(logic.APPLY_LOG, "w").close()
        launcher = Gio.SubprocessLauncher.new(Gio.SubprocessFlags.STDERR_MERGE)
        launcher.set_stdout_file_path(logic.APPLY_LOG)
        launcher.setenv("SUDO_ASKPASS", ASKPASS, True)
        launcher.setenv("TAHOE_ASKPASS_SOCK", self.askpass.path, True)
        proc = launcher.spawnv(logic.engine_argv(args))
        self.log_file = open(logic.APPLY_LOG)
        self.follow = GLib.timeout_add(200, self._read_log)
        proc.wait_check_async(None, self._on_done)

    def _read_log(self):
        for line in self.log_file.readlines():
            self._on_line(line.rstrip("\n"))
        return GLib.SOURCE_CONTINUE

    def _on_line(self, line):
        buffer = self.log.get_buffer()
        buffer.insert(buffer.get_end_iter(), line + "\n")
        self.log.scroll_to_mark(buffer.get_insert(), 0, False, 0, 0)
        event = logic.parse_progress(line)
        if event:
            kind, module_id, action = event
            title = self.meta.get(module_id, {}).get("title", "Getting ready")
            if kind == "start":
                self.progress_label.set_label(f"{'Removing' if action == 'remove' else 'Installing'}: {title}")
            elif kind == "ok":
                self.progress_done += 1
                self.progress.set_fraction(self.progress_done / self.progress_total)
            else:
                self.events.append((kind, module_id))

    def _on_done(self, proc, result):
        try:
            ok = proc.wait_check_finish(result)
        except GLib.Error:
            ok = False
        GLib.source_remove(self.follow)
        self._read_log()
        self.log_file.close()
        self.askpass.close()
        self.running = False
        self.close_button.set_sensitive(True)
        message = logic.result_message(ok, self.events, lambda m: self.meta.get(m, {}).get("title", m))
        self.progress_label.set_label(message)
        if ok:
            self.progress.set_fraction(1)
            installed = [m for m, a in logic.plan(self.current, self.wanted) if a == "install"]
            self._show_next_steps(logic.next_steps(installed, self.meta))
        self.images = {}
        self._load_status()
        self._refresh()

    def _show_next_steps(self, steps):
        body = "\n\n".join(f"{i}. {step}" for i, step in enumerate(steps, 1))
        dialog = Adw.AlertDialog(heading="Next steps", body=body)
        dialog.add_response("ok", "Got it")
        dialog.present(self)


def install_desktop_file():
    apps = os.path.join(GLib.get_user_data_dir(), "applications")
    os.makedirs(apps, exist_ok=True)
    launcher = os.path.join(logic.REPO_DIR, "tahoe-kit")
    with open(os.path.join(apps, f"{APP_ID}.desktop"), "w") as f:
        f.write("[Desktop Entry]\nType=Application\nName=Tahoe Kit\n"
                "Comment=Turn the Tahoe theme kit's modules on and off\n"
                f"Exec={launcher}\nIcon=preferences-desktop-appearance\nCategories=Settings;GNOME;GTK;\n")


def main():
    if "--install-desktop-file" in sys.argv:
        install_desktop_file()
        return 0
    app = Adw.Application(application_id=APP_ID)

    def on_activate(a):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        (a.get_active_window() or KitWindow(a)).present()

    app.connect("activate", on_activate)
    return app.run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
