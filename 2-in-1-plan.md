# 2-in-1 Flip Laptop Functionality Plan

Full tablet mode implementation plan for the ASUS ZenBook Flip S UX370UAR on Linux Mint 22.1 Cinnamon (Xorg).

## Hardware Available

| Sensor | IIO Device | Purpose |
|--------|-----------|---------|
| Accelerometer (accel_3d) | `iio:device1` (`HID-SENSOR-200073`) | Screen auto-rotation |
| Hinge angle sensor | `iio:device0` (`HID-SENSOR-INT-020b`) | Tablet mode detection (lid angle) |
| Touchscreen | ELAN24CC (04F3:24CC) via I2C | Finger touch + MPP stylus |
| No `SW_TABLET_MODE` switch | — | `intel_vbtn` module not loaded, no hardware switch |

---

## 1. Auto-Rotation

### What
Automatically rotate the screen and remap touch/stylus input coordinates when the device is flipped into portrait, inverted, or landscape orientations.

### How
`iio-sensor-proxy` (already installed) exposes the accelerometer as orientation events via `monitor-sensor`. A background script reads these events and calls:
- `xrandr --output eDP-1 --rotate <direction>` to rotate the display
- `xinput set-prop <device> "Coordinate Transformation Matrix" <matrix>` on both the touchscreen and stylus to keep touch input aligned

### Coordinate Transformation Matrices

| Orientation | Matrix |
|------------|--------|
| normal | `1 0 0 0 1 0 0 0 1` |
| inverted (bottom-up) | `-1 0 1 0 -1 1 0 0 1` |
| right (right-up) | `0 1 0 -1 0 1 0 0 1` |
| left (left-up) | `0 -1 1 1 0 0 0 0 1` |

### Input Devices to Transform
```
ELAN24CC:00 04F3:24CC          # touchscreen (fingers)
ELAN24CC:00 04F3:24CC Pen      # stylus
```

### Implementation
- Script: `~/.local/bin/auto-rotate.sh`
- Autostart: `~/.config/autostart/auto-rotate.desktop`
- Dependency: `iio-sensor-proxy` (already installed)

### Verification
```bash
monitor-sensor
# Rotate device — should show: normal, left-up, right-up, bottom-up
```

---

## 2. Tablet Mode Detection

### What
Detect when the laptop is flipped past 180° (tablet/tent mode) and automatically:
- Disable the physical keyboard
- Disable the touchpad
- Optionally launch the on-screen keyboard

### How
Two approaches, in order of preference:

#### Approach A: Hinge Angle Sensor (preferred)
The `HID-SENSOR-INT-020b` hinge sensor (`iio:device0`) can report the lid angle. A script reads the raw angle value and toggles tablet mode when it exceeds 180°.

```bash
# Read hinge angle (needs testing to find exact sysfs path)
cat /sys/bus/iio/devices/iio:device0/in_angl_raw
```

#### Approach B: Accelerometer-Based (fallback)
Infer tablet mode from `monitor-sensor` orientation. When "bottom-up" is detected during a flip, trigger tablet mode. Less precise since "bottom-up" can occur in normal use.

#### Approach C: Manual Toggle (most reliable)
A script bound to a keyboard shortcut or panel button that toggles tablet mode on/off:

```bash
xinput disable "AT Translated Set 2 keyboard"
xinput disable "ELAN1200:00 04F3:3058 Touchpad"
```

And to restore:
```bash
xinput enable "AT Translated Set 2 keyboard"
xinput enable "ELAN1200:00 04F3:3058 Touchpad"
```

### Implementation
- Script: `~/.local/bin/tablet-mode.sh`
- First step: test if the hinge sensor reports usable angle values
- If hinge works: background daemon monitors angle and auto-toggles
- If not: use manual toggle bound to a key/panel button

---

## 3. On-Screen Keyboard

### What
A virtual keyboard for typing when in tablet mode (physical keyboard folded behind).

### Recommended: Onboard
Best option for Cinnamon on Xorg. Other options (squeekboard, maliit) are Wayland-only.

### Setup
```bash
sudo apt install onboard
```

### Configuration
- Layout: "Full Keyboard" or "Phone" for touch-friendly sizing
- Auto-show: Enable in Onboard Preferences > General > "Auto-show when editing text"
  - **Known issue**: auto-show is unreliable on Cinnamon (works on GNOME). May need manual toggle.
- Toggle via D-Bus:
  ```bash
  dbus-send --type=method_call --dest=org.onboard.Onboard \
    /org/onboard/Onboard/Keyboard org.onboard.Onboard.Keyboard.ToggleVisible
  ```
- Autostart: Onboard can be added to Startup Applications

### Lock Screen Keyboard
cinnamon-screensaver does not show an on-screen keyboard. Workaround:
- Configure LightDM greeter to use Onboard:
  ```bash
  # In /etc/lightdm/lightdm-gtk-greeter.conf under [greeter]:
  keyboard = onboard
  ```
- Use `dm-tool lock` instead of the default Cinnamon lock command to switch to the LightDM greeter where Onboard is available

### Integration with Tablet Mode
The tablet mode script should auto-launch Onboard when entering tablet mode and hide it when returning to laptop mode.

---

## 4. Touch Gestures

### What
Multi-finger gestures on the touchscreen for navigation in tablet mode (swipe to go back, pinch to zoom, etc.).

### Recommended: Touchegg
The **only** gesture tool that supports both touchpad AND touchscreen. Cinnamon 5.8+ integrates with it natively. `libinput-gestures` and `fusuma` are touchpad-only — useless for tablet mode.

### Setup
```bash
sudo apt install touchegg
sudo systemctl enable --now touchegg

# Optional GUI config tool
sudo apt install touche
```

### Suggested Gesture Config (`~/.config/touchegg/touchegg.conf`)

| Gesture | Fingers | Direction | Action |
|---------|---------|-----------|--------|
| Swipe | 2 | Left | Alt+Right (forward) |
| Swipe | 2 | Right | Alt+Left (back) |
| Swipe | 3 | Up | Super (Expo/overview) |
| Pinch | 2 | In | Ctrl+Minus (zoom out) |
| Pinch | 2 | Out | Ctrl+Plus (zoom in) |
| Tap | 2 | — | Right click |

---

## 5. Stylus / Pen Experience

### What
Pressure-sensitive pen input with palm rejection for note-taking and drawing.

### Current State
- Touchscreen driver: `hid-multitouch` (loaded automatically)
- Stylus device: `ELAN24CC:00 04F3:24CC Pen` (slave pointer)
- Pressure: 256 levels (ABS_PRESSURE, 0-256)
- Buttons: Pen tip (BTN_TOUCH), barrel button (BTN_STYLUS), eraser (BTN_TOOL_RUBBER)

### Palm Rejection
The ELAN digitizer should auto-suppress touch when the pen is in proximity. If not:
- Xournal++ has built-in palm rejection: Edit > Preferences > Touchscreen > "Disable touch drawing while pen is in proximity"
- Manual: `xinput disable "ELAN24CC:00 04F3:24CC"` while using pen

### Recommended Apps

| App | Package | Best For |
|-----|---------|----------|
| **Xournal++** | `xournalpp` | Note-taking, PDF annotation |
| **Krita** | `krita` | Drawing, digital art |
| **MyPaint** | `mypaint` | Sketching |

### Setup
```bash
sudo apt install xournalpp krita
```

### Xournal++ Configuration
1. Edit > Preferences > Input System: ensure pen device is set to "Pen"
2. Touchscreen tab: enable "Disable touchscreen for drawing" and "Disable touch drawing while pen is in proximity"

---

## 6. Screen Scaling for Tablet Mode

### What
Make UI elements larger and more touch-friendly when in tablet mode.

### Options
- **Text scaling**: `gsettings set org.cinnamon.desktop.interface text-scaling-factor 1.3`
- **Panel height**: `gsettings set org.cinnamon panels-height "['1:56']"`
- **Fractional scaling**: System Settings > Display > Enable Fractional Scaling > set to 125%

### Tablet UI Toggle Script
The tablet mode script can also toggle UI scaling:
```bash
# Entering tablet mode:
gsettings set org.cinnamon.desktop.interface text-scaling-factor 1.3
gsettings set org.cinnamon panels-height "['1:56']"

# Returning to laptop mode:
gsettings set org.cinnamon.desktop.interface text-scaling-factor 1.0
gsettings set org.cinnamon panels-height "['1:40']"
```

---

## 7. Lock Screen Stylus Support

### Problem
cinnamon-screensaver doesn't accept stylus input (XI2 tablet device excluded from input grab). Finger touch works.

### Solution
Use `dm-tool lock` which switches to the LightDM greeter. The greeter accepts all input types and can show Onboard.

Configure the brightness toggle (F7) or a custom shortcut to use `dm-tool lock` instead of the default Cinnamon lock.

---

## 8. GNOME as an Alternative

### Why Consider It
GNOME on Wayland has all of the above built-in:
- Auto-rotation, on-screen keyboard auto-show, tablet mode detection, touch gestures, lock screen keyboard — all native, zero scripting

### Setup (alongside Cinnamon)
```bash
sudo apt install gnome-shell gnome-session
# Choose GNOME or Cinnamon at the login screen
```

### Trade-off
- **GNOME**: Better tablet experience, worse traditional desktop
- **Cinnamon**: Better traditional desktop, tablet features need scripting
- **Best of both**: Install both, use GNOME for tablet-heavy sessions

---

## Implementation Order

| Priority | Task | Complexity | Dependencies |
|----------|------|-----------|--------------|
| 1 | Touch gestures (Touchegg) | Low | `sudo apt install touchegg touche` |
| 2 | On-screen keyboard (Onboard) | Low | `sudo apt install onboard` |
| 3 | Stylus apps (Xournal++) | Low | `sudo apt install xournalpp` |
| 4 | Auto-rotation script | Medium | `iio-sensor-proxy` (installed), script |
| 5 | Tablet mode detection | Medium-High | Test hinge sensor, write daemon |
| 6 | Lock screen fix | Medium | LightDM greeter config |
| 7 | UI scaling toggle | Low | gsettings commands in tablet mode script |
| 8 | GNOME (optional) | Low | `sudo apt install gnome-shell` |

---

## All Packages Needed

```bash
sudo apt install touchegg touche onboard xournalpp krita
```

`iio-sensor-proxy` is already installed. `inotify-tools` and `xdotool` are already available.
