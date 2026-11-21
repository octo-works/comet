#!/bin/bash
# Installs Comet onto an existing Arch system. Run as root on the target machine.
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

fail() {
  printf 'install.sh: %s\n' "$1" >&2
  exit 1
}

emit_output() {
  local connector="$1"
  local mode="$2"
  local scale mode_line
  if [ -z "$connector" ]; then
    printf '# no internal panel detected\n'
    return 0
  fi
  case "$mode" in
    2560x1440*)
      scale=1.5
      mode_line='2560x1440@60Hz'
      ;;
    1920x1080*)
      scale=1
      mode_line='1920x1080@60Hz'
      ;;
    *)
      scale=1
      mode_line=''
      ;;
  esac
  printf 'output %s {\n' "$connector"
  if [ -n "$mode_line" ]; then
    printf '    mode %s\n' "$mode_line"
  else
    printf '    # detected mode: %s\n' "${mode:-unknown}"
  fi
  printf '    scale %s\n' "$scale"
  printf '}\n'
}

detect_connector() (
  local path base mode
  shopt -s nullglob
  for path in /sys/class/drm/card*-eDP-*; do
    if [ -f "$path/status" ] && [ "$(cat "$path/status")" != connected ]; then
      continue
    fi
    base=$(basename "$path")
    mode=$(head -n 1 "$path/modes" 2>/dev/null || true)
    printf '%s\n' "${base#card*-}"
    printf '%s\n' "$mode"
    return 0
  done
)

self_check() {
  local got
  got=$(emit_output eDP-1 2560x1440)
  [ "$got" = $'output eDP-1 {\n    mode 2560x1440@60Hz\n    scale 1.5\n}' ] || fail "wqhd snippet mismatch"
  got=$(emit_output eDP-1 1920x1080)
  [ "$got" = $'output eDP-1 {\n    mode 1920x1080@60Hz\n    scale 1\n}' ] || fail "fhd snippet mismatch"
  got=$(emit_output eDP-1 1366x768)
  [ "$got" = $'output eDP-1 {\n    # detected mode: 1366x768\n    scale 1\n}' ] || fail "unknown mode snippet mismatch"
  got=$(emit_output '' '')
  [ "$got" = '# no internal panel detected' ] || fail "missing panel snippet mismatch"
  printf 'ok\n'
}

if [ "${1:-}" = --check ]; then
  self_check
  exit 0
fi
if [ $# -gt 0 ]; then
  fail "usage: install.sh [--check]"
fi
[ "$(id -u)" -eq 0 ] || fail "run as root on the target machine"
[ -f /etc/arch-release ] || fail "Comet installs onto Arch (/etc/arch-release is missing)"
ip route show default | grep -q . || fail "no default route; connect to the network first"

mapfile -t pkgs < <(grep -vE '^[[:space:]]*(#|$)' "$root/packages.txt")
[ "${#pkgs[@]}" -gt 0 ] || fail "packages.txt is empty"
pacman -S --needed --noconfirm "${pkgs[@]}"

systemctl enable --now NetworkManager.service
if systemctl cat power-profiles-daemon.service >/dev/null 2>&1; then
  systemctl disable --now power-profiles-daemon.service
fi
# tlp.service is After=multi-user.target, so enable --now cancels the start job.
systemctl enable tlp.service
tlp start

# foot warns and falls back when LANG is C. Leave a real locale alone.
if [ -f /etc/locale.conf ] && grep -q '^LANG=' /etc/locale.conf; then
  if grep -Eq '^LANG=(C|POSIX)$' /etc/locale.conf; then
    sed -i 's/^LANG=.*/LANG=C.UTF-8/' /etc/locale.conf
  fi
else
  printf 'LANG=C.UTF-8\n' >> /etc/locale.conf
fi

install -Dm755 "$root/bin/comet-session" /usr/bin/comet-session
install -Dm755 "$root/bin/comet-power" /usr/bin/comet-power
install -Dm755 "$root/bin/comet-waybar" /usr/bin/comet-waybar
install -Dm755 "$root/bin/comet-keys" /usr/bin/comet-keys
install -Dm755 "$root/bin/comet-greet" /usr/bin/comet-greet
install -Dm755 "$root/bin/comet-shell" /usr/bin/comet-shell
install -Dm644 "$root/share/sway/config" /usr/share/comet/sway/config
install -Dm644 "$root/share/waybar/config.jsonc" /usr/share/comet/waybar/config.jsonc
install -Dm644 "$root/share/waybar/style.css" /usr/share/comet/waybar/style.css
install -Dm644 "$root/share/foot/foot.ini" /etc/xdg/foot/foot.ini
install -Dm644 "$root/share/fuzzel/fuzzel.ini" /etc/xdg/fuzzel/fuzzel.ini
install -Dm644 "$root/share/swaylock/config" /etc/swaylock/config
install -Dm644 "$root/share/mako/config" /usr/share/comet/mako/config
install -Dm644 "$root/share/os-release" /usr/share/comet/os-release
install -Dm644 "$root/system/profile.d/comet.sh" /etc/profile.d/comet.sh
install -Dm644 "$root/system/logind.conf.d/comet.conf" /etc/systemd/logind.conf.d/comet.conf
install -Dm644 "$root/system/fonts/99-comet-mono.conf" /etc/fonts/conf.d/99-comet-mono.conf
install -Dm644 "$root/system/xdg-desktop-portal/portals.conf" /etc/xdg/xdg-desktop-portal/portals.conf
install -Dm644 "$root/system/pacman.hooks/comet-os-release.hook" /etc/pacman.d/hooks/comet-os-release.hook
install -Dm644 "$root/system/greetd/config.toml" /etc/greetd/config.toml
install -Dm644 "$root/system/tuigreet/config.toml" /etc/tuigreet/config.toml
install -Dm644 "$root/walls/chris-henry-bgBhzcfnvds-unsplash.jpg" /usr/share/comet/walls/chris-henry-bgBhzcfnvds-unsplash.jpg

# greetd owns the display-manager alias. Drop the previous owner, then enable greetd.
if [ -e /etc/systemd/system/display-manager.service ]; then
  systemctl disable display-manager.service || true
fi
systemctl enable greetd.service
systemctl disable getty@tty1.service || true
systemctl set-default graphical.target
if id greeter >/dev/null 2>&1; then
  usermod -s /usr/bin/nologin greeter
  install -d -o greeter -g greeter -m 0755 /var/cache/tuigreet
fi

install -d /etc/comet
mapfile -t panel < <(detect_connector)
emit_output "${panel[0]:-}" "${panel[1]:-}" > /etc/comet/sway-output.conf
cp -f /usr/share/comet/os-release /etc/os-release

printf 'Panel config:\n'
cat /etc/comet/sway-output.conf
printf 'Reboot, then log in on tty1.\n'
