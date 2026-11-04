#!/usr/bin/env python3
"""Draws the app's preview images: rough illustrations of each module, not screenshots."""

import os
import re
import sys

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf  # noqa: E402

OUT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(OUT))
W, H = 640, 400
ACCENT = "#7a3f84"

DEFS = """<defs>
<linearGradient id="day" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8ec5ff"/><stop offset=".6" stop-color="#f6c7d8"/><stop offset="1" stop-color="#ffd9a8"/></linearGradient>
<linearGradient id="night" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#141a3a"/><stop offset=".6" stop-color="#3b2458"/><stop offset="1" stop-color="#6a3b6e"/></linearGradient>
<filter id="shadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="8" stdDeviation="10" flood-opacity=".35"/></filter>
<filter id="blur"><feGaussianBlur stdDeviation="14"/></filter>
</defs>"""


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{DEFS}{body}</svg>'


def desktop(mode="night"):
    hills = "#2a1f45" if mode == "night" else "#f0a6b9"
    return (f'<rect width="{W}" height="{H}" fill="url(#{mode})"/>'
            f'<path d="M0 300 Q160 230 320 290 T640 270 V400 H0Z" fill="{hills}" opacity=".7"/>')


def topbar(mode="night", opacity=.55):
    fill = "#000" if mode == "night" else "#fff"
    text = "#fff" if mode == "night" else "#222"
    return (f'<rect width="{W}" height="24" fill="{fill}" opacity="{opacity}"/>'
            f'<text x="16" y="17" font-family="sans-serif" font-size="12" fill="{text}">Activities</text>'
            f'<text x="{W // 2}" y="17" font-family="sans-serif" font-size="12" fill="{text}" text-anchor="middle">Tue 10:42</text>')


def window(x, y, w, h, mode="light", radius=14, title="", shadow=True, body=""):
    bg, head, fg = ("#f6f6f6", "#e9e9e9", "#333") if mode == "light" else ("#2b2b2b", "#363636", "#ddd")
    s = ' filter="url(#shadow)"' if shadow else ""
    return (f'<g{s}><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{bg}"/>'
            f'<path d="M{x} {y + radius} a{radius} {radius} 0 0 1 {radius} -{radius} h{w - 2 * radius} a{radius} {radius} 0 0 1 {radius} {radius} v{26 - radius} h-{w}z" fill="{head}"/>'
            f'<circle cx="{x + 16}" cy="{y + 13}" r="5" fill="#ff5f57"/><circle cx="{x + 32}" cy="{y + 13}" r="5" fill="#febc2e"/>'
            f'<circle cx="{x + 48}" cy="{y + 13}" r="5" fill="#28c840"/>'
            f'<text x="{x + w / 2}" y="{y + 17}" font-family="sans-serif" font-size="11" fill="{fg}" text-anchor="middle">{title}</text>'
            f'{body}</g>')


def lines(x, y, n, w, color, gap=18):
    return "".join(f'<rect x="{x}" y="{y + i * gap}" width="{w - (i % 3) * 40}" height="8" rx="4" fill="{color}" opacity=".5"/>' for i in range(n))


def files_body(x, y, w, h, mode, accent=ACCENT):
    fg = "#555" if mode == "light" else "#aaa"
    side = "#ececec" if mode == "light" else "#252525"
    icons = "".join(
        f'<path d="M{x + 160 + c * 90} {y + 60 + r * 80} h22 l8 8 h30 v40 h-60z" fill="{accent}" opacity=".85"/>'
        for r in range(2) for c in range(3) if 160 + c * 90 + 60 < w)
    return (f'<rect x="{x}" y="{y + 26}" width="130" height="{h - 26}" fill="{side}"/>'
            f'{lines(x + 16, y + 46, 6, 100, fg, 22)}{icons}')


def dock(y=350, opacity=.55):
    icons = "".join(f'<rect x="{220 + i * 42}" y="{y + 8}" width="32" height="32" rx="9" fill="{c}"/>'
                    for i, c in enumerate(["#4a90e2", "#f5a623", "#7ed321", "#bd10e0", "#50e3c2"]))
    return (f'<rect x="210" y="{y}" width="220" height="48" rx="16" fill="#fff" opacity="{opacity}" filter="url(#shadow)"/>{icons}')


def scene_theme():
    left = window(30, 60, 280, 280, "light", title="Files", body=files_body(30, 60, 280, 280, "light"))
    right = window(330, 60, 280, 280, "dark", title="Files", body=files_body(330, 60, 280, 280, "dark"))
    return svg(desktop("day") + f'<rect x="{W // 2}" width="{W // 2}" height="{H}" fill="url(#night)"/>' + topbar("night", .3) + left + right)


def scene_wallpaper():
    return svg(desktop("day") + f'<path d="M{W} 0 V{H} H0Z" fill="url(#night)"/>'
               '<circle cx="120" cy="110" r="40" fill="#ffe08a"/><circle cx="520" cy="290" r="34" fill="#f2f2ff"/>'
               '<circle cx="534" cy="280" r="30" fill="#2d2350"/>' + topbar("night", .3))


def scene_dock():
    return svg(desktop("night") + topbar() + window(120, 60, 400, 250, "dark", title="Files", body=files_body(120, 60, 400, 250, "dark")) + dock())


def scene_blur():
    blobs = '<g filter="url(#blur)"><circle cx="420" cy="80" r="70" fill="#ff7ab6"/><circle cx="540" cy="140" r="60" fill="#6ec3ff"/></g>'
    menu = ('<rect x="380" y="34" width="230" height="200" rx="18" fill="#fff" opacity=".25"/>'
            + "".join(f'<rect x="{400 + c * 70}" y="{54 + r * 58}" width="60" height="44" rx="14" fill="#fff" opacity=".35"/>'
                      for r in range(3) for c in range(3)))
    return svg(desktop("night") + '<circle cx="420" cy="80" r="70" fill="#ff7ab6"/><circle cx="540" cy="140" r="60" fill="#6ec3ff"/>'
               + blobs + topbar(opacity=.25) + menu)


def scene_corners():
    return svg(desktop("day") + window(40, 70, 260, 250, "light", radius=2, shadow=False, title="before", body=lines(60, 120, 7, 200, "#666"))
               + window(340, 70, 260, 250, "light", radius=18, title="after", body=lines(360, 120, 7, 200, "#666")))


def scene_hidetopbar():
    return svg(desktop("night") + window(0, 0, W, 360, "dark", radius=0, shadow=False, title="Maximized window", body=lines(30, 60, 12, 500, "#aaa", 22))
               + '<g opacity=".9"><rect width="640" height="24" fill="#000" opacity=".6"/>'
               + '<text x="320" y="17" font-family="sans-serif" font-size="12" fill="#fff" text-anchor="middle">mouse at the top → the bar slides in</text></g>')


def scene_coverflow():
    cards = ""
    for i, (x, skew, mode) in enumerate([(70, 18, "light"), (225, 0, "dark"), (400, -18, "light")]):
        cards += f'<g transform="translate({x + 85} 200) skewY({skew}) translate({-x - 85} -200)">{window(x, 110, 170 if i != 1 else 190, 180, mode, title="Window")}</g>'
    return svg(desktop("night") + '<rect width="640" height="400" fill="#000" opacity=".35"/>' + cards)


def scene_wobbly(level):
    x, y, w, h, bend = 170, 70, 300, 230, [0, 26, 48][level]
    path = (f'M{x} {y + 14} Q{x} {y} {x + 14} {y} L{x + w - 14} {y - bend * .4} Q{x + w} {y - bend * .4} {x + w} {y + 14 - bend * .4} '
            f'Q{x + w + bend} {y + h / 2} {x + w} {y + h} L{x} {y + h} Q{x - bend * .6} {y + h / 2} {x} {y + 14}Z')
    return svg(desktop("day") + f'<path d="{path}" fill="#f6f6f6" filter="url(#shadow)"/>'
               f'<circle cx="{x + 16}" cy="{y + 12}" r="5" fill="#ff5f57"/><circle cx="{x + 32}" cy="{y + 12}" r="5" fill="#febc2e"/>'
               f'<circle cx="{x + 48}" cy="{y + 12}" r="5" fill="#28c840"/>' + lines(x + 24, y + 50, 7, 240, "#777")
               + f'<path d="M{x + w / 2} {y - 30} l0 -0" stroke="#333"/><circle cx="{x + w / 2 + bend}" cy="{y + 8}" r="6" fill="#222" opacity=".6"/>')


def scene_launcher():
    results = "".join(f'<rect x="150" y="{170 + i * 40}" width="340" height="32" rx="8" fill="#fff" opacity="{.18 if i else .3}"/>'
                      f'<rect x="160" y="{176 + i * 40}" width="20" height="20" rx="5" fill="{c}"/>'
                      f'<text x="192" y="{191 + i * 40}" font-family="sans-serif" font-size="13" fill="#fff">{t}</text>'
                      for i, (c, t) in enumerate([("#4a90e2", "Files"), ("#f5a623", "Firefox"), ("#7ed321", "Settings")]))
    return svg(desktop("night") + topbar() + window(60, 50, 520, 300, "dark", title="Text Editor", body=lines(90, 100, 10, 440, "#aaa", 22))
               + '<rect x="130" y="100" width="380" height="200" rx="18" fill="#242424" opacity=".6" filter="url(#shadow)"/>'
               + '<text x="160" y="148" font-family="sans-serif" font-size="20" fill="#fff">fi</text>'
               + '<text x="476" y="148" font-family="sans-serif" font-size="11" fill="#bbb" text-anchor="end">Super+Space</text>' + results)


def scene_switch(mode):
    win = window(140, 60, 360, 260, "light" if mode == "day" else "dark", title="Files",
                 body=files_body(140, 60, 360, 260, "light" if mode == "day" else "dark"))
    label = "Dark Style: off" if mode == "day" else "Dark Style: on"
    return svg(desktop(mode) + topbar("night" if mode == "night" else "day", .4) + win
               + f'<rect x="450" y="32" width="170" height="34" rx="17" fill="{ACCENT}"/>'
               f'<text x="535" y="54" font-family="sans-serif" font-size="13" fill="#fff" text-anchor="middle">{label}</text>')


def scene_gtk4():
    body = files_body(100, 70, 440, 260, "light")
    dark = files_body(100, 70, 440, 260, "dark")
    return svg(desktop("day") + window(100, 70, 440, 260, "light", title="Files (open)", body=body)
               + f'<clipPath id="half"><rect x="320" y="70" width="220" height="260"/></clipPath>'
               f'<g clip-path="url(#half)">{window(100, 70, 440, 260, "dark", title="Files (open)", shadow=False, body=dark)}</g>'
               + '<text x="320" y="362" font-family="sans-serif" font-size="14" fill="#333" text-anchor="middle">switches live, no restart</text>')


def scene_ghostty():
    prompt = ('<text x="80" y="120" font-family="monospace" font-size="14" fill="#c992da">you@tahoe</text>'
              '<text x="190" y="120" font-family="monospace" font-size="14" fill="#82a8f5">~/projects</text>'
              '<text x="290" y="120" font-family="monospace" font-size="14" fill="#e4deee">$ ls</text>'
              '<text x="80" y="146" font-family="monospace" font-size="14" fill="#8fd18a">app  docs  lib  tests</text>')
    return svg(desktop("night") + topbar() + window(60, 60, 520, 280, "dark", title="Ghostty", body=f'<rect x="60" y="86" width="520" height="254" fill="#1d1a24"/>{prompt}'))


def scene_gdm():
    return svg('<rect width="640" height="400" fill="url(#night)"/><rect width="640" height="400" fill="#000" opacity=".45"/>'
               + topbar(opacity=0) + '<circle cx="320" cy="150" r="42" fill="#9b8bb4"/><circle cx="320" cy="138" r="16" fill="#e9e2f3"/>'
               '<path d="M290 178 q30 -30 60 0" fill="#e9e2f3"/>'
               '<text x="320" y="225" font-family="sans-serif" font-size="16" fill="#fff" text-anchor="middle">You</text>'
               '<rect x="220" y="245" width="200" height="34" rx="17" fill="#fff" opacity=".18"/>'
               '<text x="240" y="267" font-family="sans-serif" font-size="12" fill="#ddd">Password</text>')


def scene_plymouth():
    return svg(f'<rect width="640" height="400" fill="#000"/><circle cx="320" cy="170" r="46" fill="none" stroke="#fff" stroke-width="6"/>'
               '<text x="320" y="186" font-family="sans-serif" font-size="40" font-weight="bold" fill="#fff" text-anchor="middle">N</text>'
               f'<rect x="240" y="290" width="160" height="6" rx="3" fill="#333"/><rect x="240" y="290" width="100" height="6" rx="3" fill="{ACCENT}"/>')


def scene_nvidia():
    def buttons(x, border):
        return "".join(f'<rect x="{x}" y="{130 + i * 50}" width="200" height="36" rx="10" fill="#363636" stroke="{border}" stroke-width="2"/>'
                       for i in range(3))
    return svg(desktop("night") + window(40, 70, 260, 260, "dark", title="before", body=buttons(70, "#f4f4f4"))
               + window(340, 70, 260, 260, "dark", title="after", body=buttons(370, "#444")))


def scene_variant(accent):
    return svg(desktop("day") + window(70, 50, 500, 300, "light", title="Files", body=files_body(70, 50, 500, 300, "light", accent))
               + f'<rect x="420" y="300" width="120" height="32" rx="10" fill="{accent}"/>'
               '<text x="480" y="321" font-family="sans-serif" font-size="13" fill="#fff" text-anchor="middle">Open</text>')


def write(name, text):
    svg_path = os.path.join(OUT, name + ".svg")
    with open(svg_path, "w") as f:
        f.write(text)
    GdkPixbuf.Pixbuf.new_from_file_at_size(svg_path, W, H).savev(os.path.join(OUT, name + ".png"), "png", [], [])
    os.unlink(svg_path)


def main():
    scenes = {
        "theme": scene_theme(), "wallpaper": scene_wallpaper(), "dock": scene_dock(), "blur": scene_blur(),
        "corners": scene_corners(), "hidetopbar": scene_hidetopbar(), "coverflow": scene_coverflow(),
        "launcher": scene_launcher(), "switch-1": scene_switch("day"), "switch-2": scene_switch("night"),
        "gtk4": scene_gtk4(), "ghostty": scene_ghostty(), "gdm": scene_gdm(), "plymouth": scene_plymouth(),
        "nvidia": scene_nvidia(),
    }
    for level in range(3):
        scenes[f"wobbly-{level + 1}"] = scene_wobbly(level)
    for conf in sorted(os.listdir(os.path.join(REPO, "variants"))):
        with open(os.path.join(REPO, "variants", conf)) as f:
            accent = re.search(r"^ACCENT_HEX='?(#[0-9a-fA-F]{6})", f.read(), re.M).group(1)
        scenes["variant-" + conf[:-5]] = scene_variant(accent)
    for name, text in scenes.items():
        write(name, text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
