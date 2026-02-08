# ASUS ZenBook Flip S (Q325UAR / UX370UAR) Setup

My personal device configuration and power optimization setup for Linux Mint on the ASUS ZenBook 13 Flip.

## Device

<p align="center">
  <img src="images/front.png" width="280" alt="Front view">
  <img src="images/angle.png" width="280" alt="Angle view">
  <img src="images/variant.png" width="280" alt="Tent mode">
</p>

<p align="center">
  <img src="images/feature.jpg" width="500" alt="Lid closed with stylus">
</p>

## Hardware Specs

| Component | Detail |
|-----------|--------|
| **Model** | ASUS ZenBook Flip S Q325UAR (UX370UAR) |
| **CPU** | Intel Core i7-8550U @ 1.80GHz (4 cores / 8 threads, Kaby Lake R) |
| **GPU** | Intel UHD Graphics 620 (integrated only) |
| **RAM** | 16 GB |
| **Storage** | SanDisk SD8SN8U512G1002 512GB SSD |
| **Display** | 13.3" 1920x1080 touchscreen (convertible) |
| **WiFi** | Intel Wireless 8260 |
| **Bluetooth** | Intel 8260 (via USB) |
| **Webcam** | IMC Networks USB2.0 VGA UVC WebCam |

## Battery

| Spec | Value |
|------|-------|
| **Part Number** | C21N1624 |
| **Type** | 2-cell Li-ion |
| **Voltage** | 7.7V |
| **Design Capacity** | 39 Wh (5070 mAh) |
| **Current Capacity** | 30.3 Wh (77.6% health) |
| **Charge Cycles** | 407 |
| **Replacement** | C21N1624 (39 Wh only, no higher capacity available) |

## Operating System

| | |
|---|---|
| **OS** | Linux Mint 22.1 (Xia) |
| **Base** | Ubuntu Noble (24.04) |
| **Kernel** | 6.8.0-63-generic |
| **Desktop** | Cinnamon (Xorg) |

## Power Optimization

### Active Services

| Service | Purpose | Status |
|---------|---------|--------|
| **TLP** | Automated power management (CPU, USB, WiFi, disk) | Enabled |
| **thermald** | Intel thermal management and CPU throttling | Enabled |
| **powertop-autotune** | Applies powertop power-saving tunables at boot | Enabled |

### Setup Commands

```bash
# Install power management tools
sudo apt install tlp tlp-rdw powertop

# Enable TLP and prevent conflicts
sudo systemctl enable --now tlp
sudo systemctl mask power-profiles-daemon

# Calibrate powertop (must be on battery)
sudo powertop --calibrate
sudo powertop --auto-tune

# Create powertop systemd service
sudo tee /etc/systemd/system/powertop-autotune.service << 'EOF'
[Unit]
Description=PowerTOP auto-tune
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now powertop-autotune.service
```

### Battery Charge Limit

Set to 85% via TLP to preserve long-term battery health. The charge threshold is exposed by the `asus-nb-wmi` kernel module and TLP writes to it at boot.

```bash
# Uncomment and set in /etc/tlp.conf:
sudo sed -i 's/^#STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=85/' /etc/tlp.conf

# Apply immediately:
sudo tlp start

# Verify:
cat /sys/class/power_supply/BAT0/charge_control_end_threshold
# Should output: 85
```

> **Note:** Some ASUS laptops silently ignore thresholds other than 40, 60, or 80. If the battery charges past the set limit, change the value to 80.

### Undervolting

The i7-8550U supports undervolting via MSR 0x150 (OC Mailbox) using [intel-undervolt](https://github.com/kitsunyan/intel-undervolt). However, the kernel's early microcode update (`0xf6`) locks the undervolt register as part of the Plundervolt (CVE-2019-11157) mitigation — even though the BIOS (version 300) is pre-patch.

To re-enable undervolting, microcode loading is disabled via GRUB:

```bash
# In /etc/default/grub:
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash dis_ucode_ldr"

sudo update-grub
sudo reboot
```

This disables mitigations for SRBDS and GDS, which are local-only attack vectors and low risk on a personal laptop.

After reboot, install and configure intel-undervolt:

```bash
cd /tmp
git clone https://github.com/kitsunyan/intel-undervolt.git
cd intel-undervolt
./configure --enable-systemd
make
sudo make install
```

Configure `/etc/intel-undervolt.conf` with the stable values determined through testing:

```
undervolt 0 'CPU' -100
undervolt 1 'GPU' -80
undervolt 2 'CPU Cache' -100
undervolt 3 'System Agent' 0
undervolt 4 'Analog I/O' 0
```

Apply and verify:

```bash
sudo intel-undervolt apply
sudo intel-undervolt read
```

Enable at boot and after suspend/resume:

```bash
sudo systemctl enable intel-undervolt.service
sudo systemctl enable intel-undervolt-loop.service
```

Stability was verified with `stress-ng`:

```bash
stress-ng --cpu 0 --cpu-method all --timeout 2m --metrics-brief
```

> **Note:** -120 mV on core/cache caused a crash on this chip. -100 mV passed stress testing with 0 failures, leaving a 20 mV margin from the instability threshold.

### Fn / Media Key Remapping

#### The Problem

On this laptop, the F-row defaults to F1-F12 and requires holding Fn for media keys (volume, brightness, etc.). The Fn key is handled entirely by the embedded controller (EC) at the firmware level and is invisible to Linux.

Two issues had to be solved:

1. **The EC was swallowing media key events** — when pressing Fn+media keys, the EC handled the action internally (changing brightness/volume at the hardware level) without sending WMI notifications to the OS. The `Asus WMI hotkeys` input device existed but never fired events.

2. **Swapping F-keys and media keys** — making bare keypresses send media functions and Fn+key send F1-F12.

#### What Didn't Work

- **`asus_wmi fnlock_default=N/Y`** — The UX370UAR BIOS (version 300) does not support the `ASUS_WMI_DEVID_FNLOCK` WMI method. The parameter is accepted but the firmware ignores it.
- **`Fn+Esc` toggle** — Not functional on this model.
- **`asusctl`** — Designed for 2020+ ROG/TUF laptops, not applicable.
- **`asus-wmi-dkms` / `acpi4asus-dkms`** — Outdated, no UX370-specific patches.
- **`xbindkeys`** — Cinnamon's key grabs take priority, preventing xbindkeys from intercepting F-keys.
- **Cinnamon custom keybindings** — Also failed to intercept bare F-keys.

#### Solution Part 1: `acpi_osi=` Kernel Parameter

The BIOS DSDT contains `_OSI("Windows 2015")` conditional logic. When the kernel reports Windows 10 compatibility, the EC takes the modern code path and handles media keys internally. Setting `acpi_osi=` (empty, with trailing space) disables all `_OSI` responses, forcing the DSDT into the legacy code path where the EC sends WMI notifications to the OS.

```bash
# In /etc/default/grub (note the trailing space after =):
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash dis_ucode_ldr acpi_osi= "

sudo update-grub
sudo reboot
```

After reboot, verify WMI events are coming through:

```bash
sudo evtest /dev/input/event11  # Asus WMI hotkeys
# Press Fn+F12 — should show KEY_VOLUMEUP events
```

#### Solution Part 2: Bidirectional `xmodmap` Swap

With WMI events now reaching X11, both the F-key keycodes (from bare keypresses) and the media keycodes (from Fn+keypresses via WMI) are visible. `xmodmap` swaps them at the X11 keycode level:

- Without Fn: F-key keycodes are remapped to media keysyms
- With Fn: WMI media keycodes are remapped back to F-key keysyms

`~/.Xmodmap`:

```
! F1 <-> Sleep
keycode 67 = XF86Sleep F1
keycode 150 = F1 XF86Sleep

! F2 <-> Airplane/WLAN
keycode 68 = XF86RFKill F2
keycode 255 = F2 XF86RFKill

! F3 <-> Keyboard backlight down
keycode 69 = XF86KbdBrightnessDown F3
keycode 237 = F3 XF86KbdBrightnessDown

! F4 <-> Keyboard backlight up
keycode 70 = XF86KbdBrightnessUp F4
keycode 238 = F4 XF86KbdBrightnessUp

! F5 <-> Brightness down
keycode 71 = XF86MonBrightnessDown F5
keycode 232 = F5 XF86MonBrightnessDown

! F6 <-> Brightness up
keycode 72 = XF86MonBrightnessUp F6
keycode 233 = F6 XF86MonBrightnessUp

! F7 <-> Display off
keycode 73 = XF86DisplayOff F7
keycode 253 = F7 XF86DisplayOff

! F8 <-> Display switch (mirror/extend)
keycode 74 = XF86Display F8
keycode 235 = F8 XF86Display

! F9 <-> Touchpad toggle
keycode 75 = XF86TouchpadToggle F9
keycode 199 = F9 XF86TouchpadToggle

! F10 <-> Mute
keycode 76 = XF86AudioMute F10
keycode 121 = F10 XF86AudioMute

! F11 <-> Volume down
keycode 95 = XF86AudioLowerVolume F11
keycode 122 = F11 XF86AudioLowerVolume

! F12 <-> Volume up
keycode 96 = XF86AudioRaiseVolume F12
keycode 123 = F12 XF86AudioRaiseVolume
```

Apply and persist across logins:

```bash
xmodmap ~/.Xmodmap
```

Autostart entry (`~/.config/autostart/xmodmap.desktop`):

```ini
[Desktop Entry]
Type=Application
Name=Xmodmap Media Keys
Exec=xmodmap /home/shahmir/.Xmodmap
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=3
```

#### F-Row Key Map

| Key | Without Fn (media) | With Fn (function) |
|-----|-------------------|-------------------|
| F1 | Sleep | F1 |
| F2 | Airplane mode | F2 |
| F3 | Keyboard backlight down | F3 |
| F4 | Keyboard backlight up | F4 |
| F5 | Display brightness down | F5 |
| F6 | Display brightness up | F6 |
| F7 | Display off | F7 |
| F8 | Display switch (mirror/extend) | F8 |
| F9 | Touchpad toggle | F9 |
| F10 | Mute | F10 |
| F11 | Volume down | F11 |
| F12 | Volume up | F12 |

### Bluetooth Power Saving

```bash
rfkill block bluetooth    # Disable when not in use
rfkill unblock bluetooth  # Re-enable
```

## Touchpad

The laptop has an ELAN1200 (04F3:3058) touchpad connected via I2C. There are three X11 input drivers available on Linux. This system uses **Synaptics**.

### Driver Comparison

#### libinput

The modern default driver on most Linux distros. Minimal configuration, works out of the box.

**Pros:**
- Actively maintained, used by both X11 and Wayland
- Good multi-touch gesture support
- Minimal setup required
- Handles most hardware well with no config

**Cons:**
- Limited configuration options compared to Synaptics
- Acceleration curve can feel off on some hardware (ELAN1200 falls back to a generic curve)
- No per-axis scroll speed control
- No circular scrolling
- No pressure-based cursor speed

**Install:**
```bash
sudo apt install xserver-xorg-input-libinput
```

**Configuration** (`/etc/X11/xorg.conf.d/40-libinput.conf`):
```
Section "InputClass"
    Identifier "libinput touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"                  # Tap to click
    Option "TappingDrag" "on"              # Tap and drag
    Option "NaturalScrolling" "true"       # Reverse scroll direction
    Option "ScrollMethod" "twofinger"      # twofinger | edge | none
    Option "DisableWhileTyping" "true"     # Palm rejection while typing
    Option "AccelProfile" "adaptive"       # adaptive | flat
    Option "AccelSpeed" "0.0"             # -1.0 (slow) to 1.0 (fast)
    Option "ClickMethod" "buttonareas"     # buttonareas | clickfinger
EndSection
```

**Runtime tweaks via xinput:**
```bash
# List properties
xinput list-props "ELAN1200:00 04F3:3058 Touchpad"

# Set acceleration profile (0,1,0 = adaptive; 1,0,0 = flat)
xinput set-prop <id> "libinput Accel Profile Enabled" 0, 1, 0

# Set acceleration speed (-1.0 to 1.0)
xinput set-prop <id> "libinput Accel Speed" 0.5

# Set scroll pixel distance (lower = faster scroll)
xinput set-prop <id> "libinput Scrolling Pixel Distance" 15
```

---

#### Synaptics (currently active)

The legacy driver with the most configuration options. Better acceleration feel on some hardware.

**Pros:**
- Fine-grained control over acceleration (MinSpeed, MaxSpeed, AccelFactor)
- Per-axis scroll distance tuning
- Pressure-sensitive cursor speed
- Circular scrolling support
- Coasting (momentum scrolling) with adjustable friction
- Edge scrolling zones
- Better feel than libinput on ELAN touchpads in many cases

**Cons:**
- No longer actively developed (maintenance mode)
- X11 only, will not work on Wayland
- No built-in gesture support (need libinput-gestures or fusuma separately)
- Can conflict with libinput if both are installed without proper priority config

**Install:**
```bash
sudo apt install xserver-xorg-input-synaptics
```

**Configuration** (`/etc/X11/xorg.conf.d/70-synaptics.conf`):
```
Section "InputClass"
    Identifier "touchpad"
    Driver "synaptics"
    MatchIsTouchpad "on"
    Option "TapButton1" "1"              # 1-finger tap = left click
    Option "TapButton2" "3"              # 2-finger tap = right click
    Option "TapButton3" "2"              # 3-finger tap = middle click
    Option "VertTwoFingerScroll" "on"
    Option "HorizTwoFingerScroll" "on"
    Option "NaturalScrolling" "on"       # Reverse scroll direction
    Option "PalmDetect" "on"
    Option "PalmMinWidth" "4"            # Min finger width to trigger palm rejection
    Option "PalmMinZ" "50"               # Min pressure to trigger palm rejection
    Option "MinSpeed" "1"                # Minimum cursor speed multiplier
    Option "MaxSpeed" "1.75"             # Maximum cursor speed multiplier
    Option "AccelFactor" "0.05"          # Acceleration ramp-up rate
    Option "CoastingSpeed" "20"          # Momentum scroll speed (0 = disabled)
    Option "CoastingFriction" "50"       # How quickly coasting stops
EndSection
```

**Runtime tweaks via synclient:**
```bash
# List all options and current values
synclient -l

# Acceleration
synclient MinSpeed=1 MaxSpeed=2.0 AccelFactor=0.06

# Scroll speed (negative = natural scrolling, lower abs value = faster)
synclient VertScrollDelta=-50 HorizScrollDelta=50

# Palm detection sensitivity
synclient PalmDetect=1 PalmMinWidth=4 PalmMinZ=50

# Tap timing (ms)
synclient MaxTapTime=180 MaxDoubleTapTime=180

# Coasting (momentum scroll)
synclient CoastingSpeed=20 CoastingFriction=50

# Disable touchpad
synclient TouchpadOff=1   # 0=on, 1=off, 2=disable tap/scroll only
```

---

#### evdev

The generic Linux input driver. No touchpad-specific features.

**Pros:**
- Works with any input device
- Extremely simple and predictable
- Lowest overhead

**Cons:**
- No tap-to-click
- No two-finger scrolling
- No palm detection
- No acceleration tuning beyond basic X11 pointer settings
- Not suitable for touchpad use

**Install:**
```bash
sudo apt install xserver-xorg-input-evdev
```

evdev is only useful as a fallback if both libinput and Synaptics fail. Not recommended for touchpad use.

---

### Which Driver to Use

| Use case | Driver |
|----------|--------|
| Default / Wayland / minimal config | libinput |
| Want fine-grained acceleration and scroll tuning on X11 | Synaptics |
| Planning to switch to Wayland in the future | libinput |
| Fallback only | evdev |

### Switching Drivers

To switch from Synaptics back to libinput:
```bash
sudo rm /etc/X11/xorg.conf.d/70-synaptics.conf
sudo apt remove xserver-xorg-input-synaptics
# Log out and back in
```

To switch from libinput to Synaptics:
```bash
sudo apt install xserver-xorg-input-synaptics
# Create /etc/X11/xorg.conf.d/70-synaptics.conf (see config above)
# Log out and back in
```

## Theming

Desktop ricing is managed in a separate repo: [shahmir-k/linux-mint-ricing](https://github.com/shahmir-k/linux-mint-ricing)

<p align="center">
  <img src="images/desktop.png" width="700" alt="Desktop screenshot">
</p>

## Tools Reference

| Tool | Use |
|------|-----|
| `powertop` | Power consumption analysis and diagnostics |
| `tlp-stat -s` | TLP status overview |
| `tlp-stat -b` | Battery status and health |
| `upower -i /org/freedesktop/UPower/devices/battery_BAT0` | Detailed battery info |
| `sudo powertop --auto-tune` | Apply all power-saving tunables |
| `sensors` | CPU temperature readings |

## Not Needed

| Tool | Reason |
|------|--------|
| auto-cpufreq | TLP handles CPU governor management |
| envycontrol / bbswitch | No discrete GPU |
| hdparm | SSD, not spinning disk |
| nvidia-smi | No NVIDIA GPU |
| power-profiles-daemon | Conflicts with TLP |
