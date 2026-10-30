#!/usr/bin/env bash
# Builds every package in build-order inside an Arch container and writes a
# pacman repo to ./out. Run as root; builds run as the user "builder".
set -euo pipefail

REPO=navjottomer
OUT=$PWD/out

pacman -Syu --noconfirm --needed base-devel git pacman-contrib gnupg >/dev/null
id builder >/dev/null 2>&1 || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder

mkdir -p "$OUT"
cp -r pkgbuilds /home/builder/pkgbuilds
chown -R builder /home/builder/pkgbuilds "$OUT"

while read -r pkg; do
  [ -n "$pkg" ] || continue
  echo "::group::$pkg"
  su builder -c "cd /home/builder/pkgbuilds/$pkg && makepkg -s --noconfirm --needed -f"
  # Later packages need the earlier ones installed.
  pacman -U --noconfirm --needed /home/builder/pkgbuilds/$pkg/*.pkg.tar.zst
  cp /home/builder/pkgbuilds/$pkg/*.pkg.tar.zst "$OUT/"
  echo "::endgroup::"
done < build-order

if [ -n "${GPG_PRIVATE_KEY:-}" ]; then
  echo "$GPG_PRIVATE_KEY" | gpg --batch --import
  for f in "$OUT"/*.pkg.tar.zst; do
    gpg --batch --yes --detach-sign --no-armor "$f"
  done
  repo-add --sign "$OUT/$REPO.db.tar.zst" "$OUT"/*.pkg.tar.zst
else
  repo-add "$OUT/$REPO.db.tar.zst" "$OUT"/*.pkg.tar.zst
fi
