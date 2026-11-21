# shortcut: fish does not source /etc/profile, add this test to config.fish if a fish login should start Sway
if [ -z "$WAYLAND_DISPLAY" ] && [ "${XDG_VTNR:-0}" -eq 1 ]; then
  exec /usr/bin/comet-session
fi
