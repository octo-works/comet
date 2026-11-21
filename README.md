# Comet

Comet is a Sway session for a minimal Arch install. greetd and tuigreet take tty1, with matrix rain behind the login form. The target machine is a ThinkPad X1 Carbon Gen 5. A 2560×1440 panel gets scale 1.5. A 1920×1080 panel gets scale 1.

This repository is the whole system. Re-running the installer refreshes `/usr/share/comet` and the system drop-ins.

## Before you run it

Install Arch first, with UEFI and Secure Boot off. The stock Arch kernel is unsigned. Create a normal user in the `wheel` group with sudo. Set locale and timezone in the Arch install. Connect to the network so `pacman` can reach the mirrors. `linux`, `base`, and a bootloader are the Arch installer's job.

## Install

On the target machine, as root:

```bash
./install.sh
```

The script refuses to run unless it is root, `/etc/arch-release` exists, and a default route is up. It installs [packages.txt](packages.txt) in one transaction, enables NetworkManager, tlp, and greetd, and turns power-profiles-daemon off if that unit is present. Boot is set to `graphical.target` so greetd starts. It writes `/etc/comet/sway-output.conf` from the internal panel in sysfs.

`./install.sh --check` only tests the panel snippet. It does not install anything.

Reboot. tty1 shows tuigreet, with matrix rain behind the box at 15 frames per second. The greeter user is not a desktop login. F12 is power. A shell on tty2 can start the desktop with `exec comet-session`.

## Keys

| Key | Action |
| --- | --- |
| Super+Return | foot |
| Super+Space | fuzzel |
| Super+q | close window |
| Super+e | yazi |
| Super+g | lazygit |
| Super+Shift+e | lock, suspend, reboot, poweroff |
| Super+h/j/k/l | focus |
| Super+Shift+h/j/k/l | move |
| Print | region screenshot in satty |
| Shift+Print | full screenshot in satty |
| Super+/ | hotkey window |
| 3-finger swipe up / down | previous / next workspace |

The bar is a floating Gruvbox column on the left. Icons only; hover a module for its value. The terminal face is JetBrainsMono Nerd Font Mono. If the machine has no UTF-8 locale, the installer sets `LANG=C.UTF-8` so foot does not warn about the C locale. A user config at `~/.config/sway/config` replaces the Comet sway config. `~/.config/waybar/config.jsonc` replaces the Comet bar.

## Check on the machine

After login: `swaymsg -t get_outputs`, brightness keys, closing the lid, and a screenshot. `swaylock` is the lock. The screen blanks after 20 minutes idle and locks after 10, and again before sleep.

`/etc/os-release` says `ID=comet` and `ID_LIKE=arch`. A pacman hook puts that file back after a `filesystem` upgrade.
