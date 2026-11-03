from gi.repository import GObject, Gio, Nautilus


def open_in_ghostty(path):
    item = Nautilus.MenuItem(name=f"TahoeGhostty::{path}", label="Open in Ghostty", icon="org.gnome.Terminal")
    item.connect("activate", lambda _: Gio.Subprocess.new(["ghostty", f"--working-directory={path}"], Gio.SubprocessFlags.NONE))
    return item


class TahoeGhostty(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        if len(files) != 1 or not files[0].is_directory():
            return []
        path = files[0].get_location().get_path()
        return [open_in_ghostty(path)] if path else []

    def get_background_items(self, folder):
        path = folder.get_location().get_path()
        return [open_in_ghostty(path)] if path else []
