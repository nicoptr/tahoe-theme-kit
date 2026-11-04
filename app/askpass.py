#!/usr/bin/env python3
"""SUDO_ASKPASS helper: asks the running Tahoe Kit app for the password over its private socket."""

import os
import socket
import sys

with socket.socket(socket.AF_UNIX) as s:
    s.connect(os.environ["TAHOE_ASKPASS_SOCK"])
    sys.stdout.write(s.makefile().readline())
