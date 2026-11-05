"""What the app decides without GTK: the change plan, the engine arguments, progress lines."""

import json
import os
import re

REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIEWS = os.path.join(REPO_DIR, "app", "previews")
ENGINE = os.path.join(REPO_DIR, "tahoe-engine")
APPLY_LOG = os.path.join(os.path.expanduser("~"), ".local", "share", "tahoe-theme-kit", "last-apply.log")
IMAGE_FLAGS = {"bg_light": "--bg-light", "bg_dark": "--bg-dark", "logo": "--logo"}
# keep in sync with engine_apply in lib/engine.sh
IMPLIED_OFF = {"theme": ["switch"], "gtk4": ["switch"]}


def load_modules():
    with open(os.path.join(REPO_DIR, "app", "modules.json")) as f:
        return json.load(f)


def load_variants():
    variants = []
    folder = os.path.join(REPO_DIR, "variants")
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".conf"):
            continue
        with open(os.path.join(folder, name)) as f:
            text = f.read()
        accent = re.search(r"^ACCENT_HEX='?(#[0-9a-fA-F]{6})", text, re.M)
        variants.append({"name": name[:-5], "accent_hex": accent.group(1) if accent else "#888888"})
    return variants


def with_implied(wanted):
    wanted = dict(wanted)
    for module, others in IMPLIED_OFF.items():
        if wanted.get(module) == "off":
            wanted.update({o: "off" for o in others})
    return wanted


def plan(current, wanted):
    steps = []
    for module, value in with_implied(wanted).items():
        now = current.get(module)
        if now == value or now == "unavailable":
            continue
        if value in ("on", "off"):
            if value == "on" or now == "on":
                steps.append((module, "install" if value == "on" else "remove"))
        else:
            steps.append((module, value))
    return steps


def apply_args(current, wanted, variant, images):
    args = ["apply"]
    if variant:
        args += ["--variant", variant]
    for key, flag in IMAGE_FLAGS.items():
        if images.get(key):
            args += [flag, images[key]]
    changes = sorted(plan(current, wanted))
    for module, action in changes:
        value = {"install": "on", "remove": "off"}.get(action, action)
        args.append(f"{module}={value}")
    return args


def parse_progress(line):
    m = re.fullmatch(r"@@(start|ok|fail|refused|rollback-failed) (\S+)(?: (\S+))?", line.strip())
    return (m.group(1), m.group(2), m.group(3)) if m else None


def engine_argv(args):
    # its own session: closing or killing the app must not stop a step halfway
    return ["setsid", ENGINE] + args


def result_message(ok, events, title=lambda m: m):
    """events: (kind, module) pairs from parse_progress, in order."""
    if ok:
        return "Done. Log out and back in so GNOME loads every change."
    kinds = {kind: module for kind, module in events}
    if "rollback-failed" in kinds:
        return (f"Stopped at {title(kinds['rollback-failed'])}, and putting it back failed too: "
                f"check it by hand (log: {APPLY_LOG}).")
    if "refused" in kinds:
        return f"Stopped at {title(kinds['refused'])} before it changed anything: nothing was changed there. See the log."
    if "fail" in kinds:
        return f"Stopped at {title(kinds['fail'])}. That module was put back as it was; see the log."
    return f"Stopped; see the log ({APPLY_LOG})."
