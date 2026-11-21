
# Arch + Sway on ThinkPad X1 Carbon Gen 5 (swaystation, pre-tweaked)

Goal: **minimal Arch base**, **Sway from getty** (no display manager), **swaystation** installed once with **hardware/workflow patches applied before `install.sh`**, so you only run commands—no manual dotfile editing later.

Gen 5 notes: 14" panel is usually **2560×1440 (WQHD)** or **1920×1080 (FHD)**. The configs below default to **WQHD @ scale 1.5**; an FHD block is included as comments.

---

## Phase 0 — Arch base (no DM, minimal services)

During `archinstall` or manual install, aim for:

| Choice | Setting |
|--------|---------|
| Profile | Minimal (`base` + `linux` + `linux-firmware` + `intel-ucode`) |
| Network | **NetworkManager** (swaystation expects NM scripts) |
| Boot loader | systemd-boot or GRUB |
| **Desktop** | **None** — do not install GNOME/KDE/`ly`/greetd |
| User | Normal user in `wheel`, sudo enabled |
| Extra packages (now) | `git` `sudo` `networkmanager` `vim` `intel-ucode` |

After first boot (as root), minimal enablement:

```bash
systemctl enable --now NetworkManager
pacman -Syu --noconfirm
```

Optional hardening for an old laptop (fewer background services):

```bash
systemctl disable --now bluetooth.service 2>/dev/null || true
# swaystation's installer re-enables bluetooth; disable again after install if you want
```

---

## Phase 1 — What swaystation `install.sh` does (exact order)

Path: `install_scripts/install.sh` sources and runs, in order:

| Step | Script | Action |
|------|--------|--------|
| 1 | `make_directories.sh` | Creates `~/.local/share`, `~/.config`, `~/.config.backup`, `~/Pictures/screenshots`, `~/Pictures/backgrounds` |
| 2 | `install_with_pacman.sh` | Installs **all** names from `package_lists/{common,cmus,dev,wayland,gui}.txt` via `sudo pacman -S` |
| 3 | `copy_from_src_to_des.sh` | Copies repo `config_dotfiles/` → `~/.local/share/config_dotfiles/` (prompts to overwrite if present) |
| 4 | `symlink_configs.sh` | Backs up existing configs to `~/.config.backup/<timestamp>/`, then symlinks per `db/config_dotfiles.db.json` (sway, waybar → **waybar_block_4**, rofi, foot, mako, …) |
| 5 | `install_aur_helper.sh` | **Interactive**: offers yay/paru (skip with **N** for this plan) |
| 6 | `enable_services.sh` | Enables **bluetooth** and **`ly@tty2`** (display manager — **we disable this** for getty login) |

This plan **patches the clone before step 2** and runs the installer **non-interactively** where possible.

---

## Phase 2 — One-shot prep (clone + patch + install)

Run as your normal user after Arch base is up and Wi‑Fi works (`nmcli` or `nmtui` once).

### 2.1 Clone

```bash
mkdir -p "$HOME/workstationdots"
git clone -b main --depth=1 https://github.com/mister-grimm96/swaystation \
  "$HOME/workstationdots/swaystation"
cd "$HOME/workstationdots/swaystation"
```

### 2.2 Pre-apply X1 Carbon patches (no manual editing later)

```bash
CF="$HOME/workstationdots/swaystation/config_dotfiles/config"
PL="$HOME/workstationdots/swaystation/install_scripts/package_lists"
INS="$HOME/workstationdots/swaystation/install_scripts/scripts"

# --- Lighter install for old ThinkPad: drop full dev toolchain ---
: > "$PL/dev_pkg_list.txt"

# --- Remove display manager from GUI list (getty login instead) ---
grep -v '^ly$' "$PL/gui_pkg_list.txt" > "$PL/gui_pkg_list.tmp" && mv "$PL/gui_pkg_list.tmp" "$PL/gui_pkg_list.txt"

# --- Add idle lock + Wi-Fi firmware metapackage is already in linux-firmware; ensure tools ---
grep -qxF 'swayidle' "$PL/wayland_pkg_list.txt" || echo swayidle >> "$PL/wayland_pkg_list.txt"
grep -qxF 'iw'       "$PL/common_pkg_list.txt"  || echo iw       >> "$PL/common_pkg_list.txt"

# --- devices.conf (Hi-DPI X1 Carbon Gen 5) ---
cat > "$CF/sway/devices.conf" <<'EOF'
# ThinkPad X1 Carbon Gen 5 — built-in panel (typical name eDP-1)
# WQHD 2560x1440: scale 1.5 (~ logical 1707×960)
output eDP-1 {
    mode 2560x1440@60Hz
    scale 1.5
    adaptive_sync off
}

# FHD 1920x1080 model: comment WQHD block above and use:
# output eDP-1 {
#     mode 1920x1080@60Hz
#     scale 1.0
# }

input "type:keyboard" {
    xkb_layout us
    xkb_options caps:escape
}

input "type:touchpad" {
    dwt enabled
    tap enabled
    drag enabled
    drag_lock disabled
    middle_emulation enabled
    natural_scroll enabled
}
EOF

# --- environment + swayidle in autostart ---
cat > "$CF/sway/environment.conf" <<'EOF'
# XWayland / toolkit hints for Hi-DPI (alongside output scale)
exec_always export XDG_CURRENT_DESKTOP=sway
exec_always export XDG_SESSION_TYPE=wayland
exec_always export GDK_BACKEND=wayland,x11
exec_always export QT_QPA_PLATFORM=wayland;xcb
exec_always export MOZ_ENABLE_WAYLAND=1
exec_always export WLR_DRM_NO_ATOMIC=0
EOF

# Insert include if missing
grep -q 'environment.conf' "$CF/sway/config" || \
  sed -i '/variables.conf/a include ~/.config/sway/environment.conf' "$CF/sway/config"

# Append swayidle after mako in autostart.conf
if ! grep -q swayidle "$CF/sway/autostart.conf"; then
  cat >> "$CF/sway/autostart.conf" <<'EOF'

# Idle: lock at 10m, dim at 20m, lock before sleep
exec swayidle -w \
    timeout 600 'swaylock -i ~/.config/walls/lock.png' \
    timeout 1200 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -i ~/.config/walls/lock.png'
EOF
fi

# --- Foot: slightly larger font for 14" Hi-DPI ---
sed -i 's/size=15/size=17/g' "$CF/foot/foot.ini" 2>/dev/null || true

# --- Waybar: full config with calendar tooltip (replaces block_4 default) ---
# Written in section 4 below — save to:
#   $CF/waybar_configs/waybar_block_4/config.jsonc

# --- Seed default wallpaper cache for setBackground.sh ---
mkdir -p "$CF/walls"
# ensure default wall.png exists in repo walls; point cache
# (install copies walls to ~/.config/walls)
```

Copy the **Waybar** file from [§4 Waybar config](#4-waybar-config-full-replace) into:

`$HOME/workstationdots/swaystation/config_dotfiles/config/waybar_configs/waybar_block_4/config.jsonc`

### 2.3 Non-interactive install

```bash
cd "$HOME/workstationdots/swaystation/install_scripts"
# Skip AUR helper prompts
printf 'n\n' | bash install.sh
```

If `copy_from_src_to_des` asks to overwrite and you re-run:

```bash
rm -rf "$HOME/.local/share/config_dotfiles"
printf 'y\nn\n' | bash install.sh
```

### 2.4 Post-install: drop `ly`, use getty

```bash
sudo systemctl disable ly@tty2.service 2>/dev/null || true
sudo systemctl disable getty@tty2.service 2>/dev/null || true  # optional: use tty1 only
```

### 2.5 Login shell → Sway (no DM)

```bash
cat >> "$HOME/.bash_profile" <<'EOF'

# Start Sway from getty on tty1 (after login)
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
  exec dbus-run-session sway
fi
EOF
```

Optional: default wallpaper in cache for `setBackground.sh`:

```bash
install -d "$HOME/.cache"
echo "$HOME/.config/walls/wall.png" > "$HOME/.cache/wall.txt"
cp -n "$HOME/.config/walls/"*.png "$HOME/Pictures/backgrounds/" 2>/dev/null || true
```

---

## Phase 3 — Hardware checks (Intel Wi‑Fi, panel mode)

Run once after install (still on tty):

```bash
# Wi‑Fi: Gen 5 usually Intel iwlwifi (7265 / 8265 class)
lspci -nnk | grep -A3 -i network
dmesg | grep -i iwlwifi | tail -5
pacman -Q linux-firmware intel-ucode
iw dev
nmcli radio wifi on
nmcli device wifi list

# If iwlwifi fails to load firmware: reinstall firmware & reboot
# sudo pacman -S --noconfirm linux-firmware
# reboot

# Panel: confirm output name and native mode (adjust devices.conf if not eDP-1 / WQHD)
sudo pacman -S --needed --noconfirm foot
# After first sway login: swaymsg -t get_outputs
```

If `swaymsg` shows **1920×1080** only, switch to the **FHD** block in `devices.conf` (see Phase 2.2).

---

## Phase 4 — Modified configs (paste-ready)

These match what the prep script sets; keep them if you patch by hand instead.

### `~/.config/sway/devices.conf` (via symlink from swaystation)

```conf
# ThinkPad X1 Carbon Gen 5 — built-in panel (typical name eDP-1)
output eDP-1 {
    mode 2560x1440@60Hz
    scale 1.5
    adaptive_sync off
}

# FHD variant:
# output eDP-1 {
#     mode 1920x1080@60Hz
#     scale 1.0
# }

input "type:keyboard" {
    xkb_layout us
    xkb_options caps:escape
}

input "type:touchpad" {
    dwt enabled
    tap enabled
    drag enabled
    drag_lock disabled
    middle_emulation enabled
    natural_scroll enabled
}
```

### `~/.config/sway/environment.conf` (new; add to main `config`)

```conf
exec_always export XDG_CURRENT_DESKTOP=sway
exec_always export XDG_SESSION_TYPE=wayland
exec_always export GDK_BACKEND=wayland,x11
exec_always export QT_QPA_PLATFORM=wayland;xcb
exec_always export MOZ_ENABLE_WAYLAND=1
```

Main `config` should include (after `variables.conf`):

```conf
include ~/.config/sway/environment.conf
```

### `~/.config/sway/autostart.conf` — append

```conf
exec swayidle -w \
    timeout 600 'swaylock -i ~/.config/walls/lock.png' \
    timeout 1200 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -i ~/.config/walls/lock.png'
```

Wallpaper: unchanged swaystation flow — `setBackground.sh` runs `swaybg` from `auto_start.sh`; default image `~/.config/walls/wall.png`, optional gallery under `~/Pictures/backgrounds`.

---

## 4. Waybar config (full replace)

Save as  
`config_dotfiles/config/waybar_configs/waybar_block_4/config.jsonc`  
before `install.sh` (default symlink target).

```jsonc
{
  "layer": "top",
  "height": 24,
  "spacing": 4,
  "margin-top": 5,
  "margin-right": 5,
  "margin-left": 5,
  "modules-left": [
    "custom/launcher",
    "sway/workspaces",
    "sway/window",
    "sway/mode"
  ],
  "modules-right": [
    "tray",
    "network",
    "cpu",
    "custom/cpu_temp",
    "backlight",
    "custom/memory",
    "pulseaudio",
    "battery",
    "clock"
  ],
  "custom/launcher": {
    "format": "<span ></span>",
    "on-click": "rofi -show drun -disable-history -show-icons -theme-str 'window { width: 22% ; location: northwest; margin: 10px 0 0 10px; } listview { lines: 20; }'",
    "on-click-right": "~/.config/custom_scripts/power.sh",
    "escape": true,
    "tooltip": false
  },
  "sway/workspaces": {
    "disable-scroll": true,
    "all-outputs": true,
    "format": "{icon}",
    "format-icons": {
      "1": "1", "2": "2", "3": "3", "4": "4", "5": "5",
      "6": "6", "7": "7", "8": "8", "9": "9", "10": "10"
    }
  },
  "sway/window": {
    "format": "<span color='#f6c657'> 󰣆 </span>{title}",
    "max-length": 80,
    "separate-outputs": true,
    "tooltip": false
  },
  "sway/mode": {
    "format": " {}",
    "tooltip": false
  },
  "tray": {
    "icon-size": 16,
    "spacing": 8
  },
  "cpu": {
    "format": "<span color='#e78a4e'> 󰻠 </span>{usage}%",
    "interval": 5,
    "on-click-right": "~/.config/custom_scripts/launch_tui.sh btop",
    "tooltip": false
  },
  "custom/cpu_temp": {
    "exec": "~/.config/waybar/scripts/waybarTemp.sh",
    "return-type": "json",
    "interval": 5,
    "format": "{}",
    "tooltip": false
  },
  "backlight": {
    "format": "<span color='#f6c657'> 󰃟 </span>{percent}%",
    "tooltip": false,
    "on-scroll-up": "brightnessctl set +5%",
    "on-scroll-down": "brightnessctl set 5%-"
  },
  "custom/memory": {
    "exec": "~/.config/waybar/scripts/memory_usage.sh",
    "interval": 5,
    "return-type": "json",
    "format": "<span color='#458588'>  </span>{}"
  },
  "pulseaudio": {
    "scroll-step": 2,
    "format": "<span color='#83a598'> 󰕾 </span>{volume}%",
    "format-muted": "<span color='#ea6962'> 󰖁 </span>",
    "on-click": "pactl set-sink-mute @DEFAULT_SINK@ toggle",
    "tooltip": false
  },
  "battery": {
    "interval": 30,
    "states": { "warning": 30, "critical": 15 },
    "format": "<span color='#689d6a'> {icon} </span>{capacity}%",
    "format-charging": "<span color='#689d6a'> 󰂅 </span>{capacity}%",
    "format-icons": ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  },
  "network": {
    "interval": 5,
    "format-wifi": "<span color='#d3869b'> 󰤨 </span>{essid}",
    "format-ethernet": "<span color='#d3869b'> 󰈀 </span>{ifname}",
    "format-disconnected": "<span color='#ea6962'> 󰤭 </span>offline",
    "tooltip-format-wifi": "{essid} ({signalStrength}%)\n{ifname}: {ipaddr}/{cidr}",
    "on-click": "nm-connection-editor"
  },
  "clock": {
    "format": "<span color='#8ec07c'> 󰥔 </span>{:%a %d · %H:%M}",
    "format-alt": "<span color='#8ec07c'> 󰃰 </span>{:%Y-%m-%d %H:%M:%S}",
    "tooltip-format": "<big>{:%A %B %d, %Y}</big>\n<tt>{calendar}</tt>",
    "calendar": {
      "mode": "month",
      "mode-mon-col": 3,
      "on-scroll": 1,
      "format": {
        "months": "<span color='#f6c657'><b>{}</b></span>",
        "weekdays": "<span color='#8ec07c'>{}</span>",
        "today": "<span color='#ea6962'><b><u>{}</u></b></span>"
      }
    },
    "actions": {
      "on-scroll-up": "shift_up",
      "on-scroll-down": "shift_down"
    },
    "interval": 30
  }
}
```

---

## Phase 5 — Ordered checklist: power-on → login-ready Sway

| # | Where | Command / action |
|---|--------|------------------|
| 1 | Firmware/BIOS | Enable UEFI, disable Secure Boot if iwlwifi blocked (optional) |
| 2 | Arch install | Minimal base + `linux-firmware` `intel-ucode` `NetworkManager` `git` `sudo` |
| 3 | First login (root) | `systemctl enable --now NetworkManager` |
| 4 | User | Create user, `wheel`, set password |
| 5 | Wi‑Fi test | `nmcli device wifi list` / connect |
| 6 | Clone | `git clone … swaystation` into `~/workstationdots/` |
| 7 | Patch | Run Phase 2.2 + save Waybar §4 |
| 8 | Install | `printf 'n\n' \| bash install_scripts/install.sh` |
| 9 | DM cleanup | `sudo systemctl disable ly@tty2.service` |
| 10 | Getty login | Append `.bash_profile` sway `exec` block (Phase 2.5) |
| 11 | Wallpaper cache | `echo "$HOME/.config/walls/wall.png" > ~/.cache/wall.txt` |
| 12 | Reboot | `reboot` |
| 13 | tty1 login | Username/password → **Sway starts automatically** |
| 14 | Verify | `swaymsg -t get_outputs` (scale/mode), hover Waybar clock (calendar), lock test `swaylock` |

---

## What you get out of the box (after this plan)

| Item | Status |
|------|--------|
| Lock | `swaylock` + **swayidle** (10 min / sleep) |
| Notifications | **mako** (swaystation autostart) |
| Screenshots | **grim + satty** (keymaps in swaystation) |
| Wallpaper | **swaybg** via `setBackground.sh` |
| Launcher | **rofi** |
| Terminal | **foot** (17pt on Hi-DPI) |
| Bar | **waybar** with **calendar tooltip** |
| DM | **None** — getty + `dbus-run-session sway` |
| Dev bloat | **Removed** (empty `dev_pkg_list.txt`) |

---

## If something fails on first Sway start

- **Blank or wrong scale:** Fix `devices.conf` using `swaymsg -t get_outputs` (name + current mode).
- **Wi‑Fi missing:** `dmesg \| grep iwl` → reinstall `linux-firmware`, reboot.
- **Waybar calendar empty:** Ensure Waybar ≥ 0.9 with calendar support (`pacman -Q waybar`).
- **Rofi tiny/huge:** Output `scale` drives most Wayland UI; tweak `scale` 1.25 ↔ 1.5.

I can turn Phase 2.2 into a single `x1carbon-prep-and-install.sh` in a gist-style script block if you want one file to curl and run.


```bash
# After login to Sway, idle ~2 min
ps aux --sort=-%mem | head -15
ps aux --sort=-%cpu | head -15
intel_gpu_top    # or cat /sys/kernel/debug/dri/0/i915_gem_objects 2>/dev/null
```