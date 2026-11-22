#!/usr/bin/env bash
# shellcheck disable=SC2034
# Build: sudo mkarchiso -v -w /var/tmp/comet-iso -o out iso

iso_name="comet"
iso_label="COMET_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Comet"
iso_application="Comet live"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
)

# mkarchiso sources this file on the host, then copies airootfs. Stage the
# repo where the customize script can install it inside the image.
_here=$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_repo=$(dirname "$_here")
_stage="${_here}/airootfs/root/comet"
mkdir -p "$_stage"
tar -C "$_repo" \
  --exclude iso/airootfs/root/comet \
  --exclude out \
  --exclude .git \
  -cf - . | tar -C "$_stage" -xf -
