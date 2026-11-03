#!/usr/bin/env python3
"""Usage: restack-below.py WINDOW SIBLING - asks the WM (_NET_RESTACK_WINDOW) to put WINDOW right below SIBLING."""
import ctypes, sys

x11 = ctypes.CDLL('libX11.so.6')
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XInternAtom.restype = ctypes.c_ulong
x11.XDefaultRootWindow.restype = ctypes.c_ulong


class ClientMessage(ctypes.Structure):
    _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong), ('send_event', ctypes.c_int),
                ('display', ctypes.c_void_p), ('window', ctypes.c_ulong), ('message_type', ctypes.c_ulong),
                ('format', ctypes.c_int), ('data', ctypes.c_long * 5), ('pad', ctypes.c_long * 12)]


CLIENT_MESSAGE, PAGER_SOURCE, BELOW = 33, 2, 1
SUBSTRUCTURE_NOTIFY_AND_REDIRECT = (1 << 19) | (1 << 20)

window, sibling = (int(x, 16) for x in sys.argv[1:3])
display = x11.XOpenDisplay(None)
event = ClientMessage(type=CLIENT_MESSAGE, send_event=1, display=display, window=window, format=32,
                      message_type=x11.XInternAtom(ctypes.c_void_p(display), b'_NET_RESTACK_WINDOW', 0))
event.data[:3] = [PAGER_SOURCE, sibling, BELOW]
x11.XSendEvent(ctypes.c_void_p(display), ctypes.c_ulong(x11.XDefaultRootWindow(ctypes.c_void_p(display))),
               0, ctypes.c_long(SUBSTRUCTURE_NOTIFY_AND_REDIRECT), ctypes.byref(event))
x11.XCloseDisplay(ctypes.c_void_p(display))
