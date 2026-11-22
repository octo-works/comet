#!/bin/bash
# Runs inside the image root. Packages from packages.x86_64 are already installed.
set -euo pipefail

export COMET_ISO=1
bash /root/comet/install.sh

if ! id comet >/dev/null 2>&1; then
  useradd -m -G wheel -s /usr/bin/fish comet
fi
echo 'comet:comet' | chpasswd
printf '%s\n' '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/comet-live
chmod 440 /etc/sudoers.d/comet-live

install -d /root/archinstall
if [ -d /root/comet/dmz/archinstall ]; then
  cp -a /root/comet/dmz/archinstall/. /root/archinstall/
fi

# sinkd and reflect installers returned 403 from the image build. Put them back when the URLs allow it.
# curl -fsSL https://sinkd.octoworks.dev/install.sh | sh
# curl -fsSL https://reflect.ballast.dev/install.sh | sh
