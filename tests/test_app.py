import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))
import logic  # noqa: E402

CURRENT = {"theme": "on", "switch": "on", "dock": "off", "launcher": "searchlight", "gtk4": "unavailable"}


class PlanTest(unittest.TestCase):
    def test_changes_only(self):
        wanted = dict(CURRENT, dock="on")
        self.assertEqual(logic.plan(CURRENT, wanted), [("dock", "install")])

    def test_theme_off_takes_the_switch_with_it(self):
        wanted = dict(CURRENT, theme="off")
        self.assertEqual(sorted(logic.plan(CURRENT, wanted)), [("switch", "remove"), ("theme", "remove")])

    def test_gtk4_off_takes_the_switch_with_it(self):
        current = dict(CURRENT, gtk4="on")
        wanted = dict(current, gtk4="off")
        self.assertEqual(sorted(logic.plan(current, wanted)), [("gtk4", "remove"), ("switch", "remove")])

    def test_launcher_choice(self):
        wanted = dict(CURRENT, launcher="ulauncher")
        self.assertEqual(logic.plan(CURRENT, wanted), [("launcher", "ulauncher")])

    def test_unavailable_is_never_installed(self):
        wanted = dict(CURRENT, gtk4="on")
        self.assertEqual(logic.plan(CURRENT, wanted), [])


class ApplyArgsTest(unittest.TestCase):
    def test_args_carry_variant_images_and_changes(self):
        wanted = dict(CURRENT, dock="on")
        args = logic.apply_args(CURRENT, wanted, variant="topaz", images={"bg_dark": "/d.png"})
        self.assertEqual(args, ["apply", "--variant", "topaz", "--bg-dark", "/d.png", "dock=on"])

    def test_no_variant_no_flag(self):
        args = logic.apply_args(CURRENT, dict(CURRENT, theme="off"), variant=None, images={})
        self.assertEqual(args, ["apply", "switch=off", "theme=off"])


class ProgressTest(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(logic.parse_progress("@@start dock install"), ("start", "dock", "install"))
        self.assertEqual(logic.parse_progress("@@ok dock"), ("ok", "dock", None))
        self.assertEqual(logic.parse_progress("@@fail gdm"), ("fail", "gdm", None))
        self.assertIsNone(logic.parse_progress("Reading package lists..."))


class ResultTest(unittest.TestCase):
    def test_parse_new_events(self):
        self.assertEqual(logic.parse_progress("@@refused gtk4"), ("refused", "gtk4", None))
        self.assertEqual(logic.parse_progress("@@rollback-failed gdm"), ("rollback-failed", "gdm", None))

    def test_messages_follow_what_happened(self):
        self.assertIn("Done", logic.result_message(True, []))
        self.assertIn("nothing was changed", logic.result_message(False, [("fail", "gtk4"), ("refused", "gtk4")]))
        self.assertIn("put back", logic.result_message(False, [("fail", "dock")]))
        self.assertIn("by hand", logic.result_message(False, [("fail", "gdm"), ("rollback-failed", "gdm")]))
        self.assertNotIn("put back", logic.result_message(False, []))

    def test_engine_runs_in_its_own_session(self):
        self.assertEqual(logic.engine_argv(["apply", "dock=on"]), ["setsid", logic.ENGINE, "apply", "dock=on"])


class ModulesFileTest(unittest.TestCase):
    def test_every_engine_module_has_metadata_and_previews(self):
        meta = logic.load_modules()
        ids = [m["id"] for m in meta]
        with open(os.path.join(logic.REPO_DIR, "lib", "modules.sh")) as f:
            line = next(line for line in f if line.startswith("MODULES=("))
        self.assertEqual(ids, line.strip()[len("MODULES=("):-1].split())
        for m in meta:
            for frame in m["preview"]:
                self.assertTrue(os.path.isfile(os.path.join(logic.PREVIEWS, frame)), frame)

    def test_variants_read_from_conf(self):
        variants = logic.load_variants()
        self.assertEqual([v["name"] for v in variants], ["amethyst", "ruby", "topaz"])
        self.assertEqual(variants[0]["accent_hex"], "#7a3f84")


if __name__ == "__main__":
    unittest.main()


class AskpassTest(unittest.TestCase):
    def test_password_reaches_askpass_through_a_private_socket(self):
        import stat
        import subprocess
        os.environ.pop("GDK_PIXBUF_MODULE_FILE", None)
        import tahoe_kit

        server = tahoe_kit.AskpassServer("s3cret pw")
        try:
            self.assertEqual(stat.S_IMODE(os.stat(server.path).st_mode), 0o600)
            out = subprocess.run([tahoe_kit.ASKPASS], env={"TAHOE_ASKPASS_SOCK": server.path},
                                 capture_output=True, text=True, check=True).stdout
            self.assertEqual(out, "s3cret pw\n")
        finally:
            server.close()
        self.assertFalse(os.path.exists(server.path))


@unittest.skipUnless(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"), "needs a display")
class WindowSmokeTest(unittest.TestCase):
    def test_window_builds_and_tracks_changes(self):
        os.environ.pop("GDK_PIXBUF_MODULE_FILE", None)
        import tahoe_kit
        from gi.repository import Adw

        modules = {m["id"]: "off" for m in logic.load_modules()}
        modules.update(theme="on", switch="on", launcher="searchlight", gtk4="unavailable")
        tahoe_kit.engine_status = lambda: {"variant": "amethyst", "bg_light": None, "bg_dark": None, "logo": None,
                                           "session": "wayland", "modules": modules}
        Adw.init()
        app = Adw.Application(application_id="io.github.nicoptr.TahoeKitTest")
        app.register(None)
        win = tahoe_kit.KitWindow(app)
        self.assertEqual(win.summary.get_label(), "No changes")
        win.controls["theme"].set_active(False)
        self.assertEqual(win.wanted["switch"], "off")
        self.assertEqual(win.summary.get_label(), "2 to remove")
        self.assertFalse(win.controls["gtk4"].get_sensitive())
        win.controls["switch"].set_active(True)
        self.assertEqual(win.wanted["theme"], "on")
        modules.update(gtk4="off")
        win2 = tahoe_kit.KitWindow(app)
        win2.controls["switch"].set_active(False)
        win2.controls["switch"].set_active(True)
        self.assertEqual(win2.wanted["gtk4"], "on")
        win2.destroy()
        tahoe_kit.sudo_password_ok = lambda _pw: False
        win._check_password_and_run("x")
        self.assertTrue(win.running)
        self.assertFalse(win.apply_button.get_sensitive())
        win.destroy()
