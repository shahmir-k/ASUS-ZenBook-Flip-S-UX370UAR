#!/usr/bin/env python3
"""
GPIO volume button mapper for ASUS ZenBook Flip S (UX370UAR).

Reads KEY_VOLUMEDOWN/UP from gpio-keys (/dev/input/event12) and
re-emits them as KEY_F11/F12 via a virtual uinput device named
'volume-buttons'. xmodmap then maps:
  keycode 95 (KEY_F11) → XF86AudioLowerVolume
  keycode 96 (KEY_F12) → XF86AudioRaiseVolume

This avoids conflict with Fn+F11/F12 (WMI) which use the same evdev
codes but are mapped to F11/F12 via keycode 122/123.
"""
import sys
import evdev
from evdev import ecodes, UInput

GPIO_DEVICE = '/dev/input/event12'

def main():
    try:
        gpio = evdev.InputDevice(GPIO_DEVICE)
    except FileNotFoundError:
        print(f"Device {GPIO_DEVICE} not found", file=sys.stderr)
        sys.exit(1)

    ui = UInput(
        events={ecodes.EV_KEY: [ecodes.KEY_F11, ecodes.KEY_F12]},
        name='volume-buttons',
        vendor=0x0001,
        product=0x0001,
        version=1,
    )

    gpio.grab()

    for event in gpio.read_loop():
        if event.type == ecodes.EV_KEY:
            if event.code == ecodes.KEY_VOLUMEDOWN:
                ui.write(ecodes.EV_KEY, ecodes.KEY_F12, event.value)
                ui.syn()
            elif event.code == ecodes.KEY_VOLUMEUP:
                ui.write(ecodes.EV_KEY, ecodes.KEY_F11, event.value)
                ui.syn()

if __name__ == '__main__':
    main()
