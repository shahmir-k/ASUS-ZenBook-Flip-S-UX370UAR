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

Configure `/etc/intel-undervolt.conf` with safe starting values:

```
undervolt 0 'CPU' -80
undervolt 1 'GPU' -50
undervolt 2 'CPU Cache' -80
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

> **Note:** Stress test with `mprime` (Small FFTs, then Blend) for 1-2 hours before pushing values further. Most i7-8550U chips are stable at -100 to -120 mV on core/cache. Add a 10 mV safety margin from your last stable value.

### Bluetooth Power Saving

```bash
rfkill block bluetooth    # Disable when not in use
rfkill unblock bluetooth  # Re-enable
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
