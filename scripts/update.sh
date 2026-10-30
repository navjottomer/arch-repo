#!/usr/bin/env bash
# Looks up the newest upstream version of every package. When it is newer than
# the recipe, bumps pkgver, resets pkgrel and refreshes the checksum, and makes
# one commit per package. Does not push: the workflow does that.
#
# Each pkgbuilds/<name>/upstream holds one line: "pypi <project>" or
# "github <owner>/<repo>".
set -euo pipefail

cd "$(dirname "$0")/.."

latest_version() {
  local kind=$1 id=$2
  case $kind in
    pypi)   curl -fsSL "https://pypi.org/pypi/$id/json" | jq -r .info.version ;;
    github) curl -fsSL "https://api.github.com/repos/$id/releases/latest" | jq -r .tag_name | sed 's/^v//' ;;
    *) echo "unknown source kind: $kind" >&2; return 1 ;;
  esac
}

# Prints the b2sum of the first source of a PKGBUILD, with pkgver already set.
source_sum() {
  local dir=$1
  local url
  url=$(bash -c 'source "$1"; s=${source[0]}; echo "${s#*::}"' _ "$dir/PKGBUILD")
  curl -fsSL "$url" | b2sum | cut -d' ' -f1
}

for dir in pkgbuilds/*/; do
  dir=${dir%/}
  name=${dir#pkgbuilds/}
  [ -f "$dir/upstream" ] || continue

  read -r kind id < "$dir/upstream"
  new=$(latest_version "$kind" "$id")
  current=$(sed -n 's/^pkgver=//p' "$dir/PKGBUILD")

  if [ -z "$new" ] || [ "$new" = "null" ]; then
    echo "$name: could not read the upstream version" >&2
    continue
  fi
  if [ "$new" = "$current" ] || [ "$(printf '%s\n%s\n' "$current" "$new" | sort -V | tail -1)" != "$new" ]; then
    echo "$name: $current is current"
    continue
  fi

  echo "$name: $current -> $new"
  sed -i "s/^pkgver=.*/pkgver=$new/; s/^pkgrel=.*/pkgrel=1/" "$dir/PKGBUILD"
  sum=$(source_sum "$dir")
  sed -i "s/^b2sums=.*/b2sums=('$sum')/" "$dir/PKGBUILD"

  git add "$dir/PKGBUILD"
  git commit -q -m "$name: update to $new"
done
