#!/usr/bin/env python3
"""Write ~/.config/ghostty/themes/tahoe-{dark,light} from the TERMINAL_* values of the conf in argv[1]."""
import ast
import os
import re
import sys

conf = open(sys.argv[1]).read()
out = os.path.expanduser('~/.config/ghostty/themes')
os.makedirs(out, exist_ok=True)


def colors(name):
    return re.findall(r"'(#[0-9a-fA-F]{6})'", re.search(name + r"=\((.*)\)", conf).group(1))


def palette(name):
    return ast.literal_eval(re.search(name + r'="(.*)"', conf).group(1))


for mode in ('DARK', 'LIGHT'):
    bg, fg, cursor, highlight = colors('TERMINAL_' + mode)[:4]
    lines = [f'palette = {i}={c}' for i, c in enumerate(palette(f'TERMINAL_{mode}_PALETTE'))]
    lines += [f'background = {bg}', f'foreground = {fg}', f'cursor-color = {cursor}', f'cursor-text = {bg}',
              f'selection-background = {highlight}', f'selection-foreground = {fg}']
    with open(os.path.join(out, f'tahoe-{mode.lower()}'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
