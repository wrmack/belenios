#!/bin/sh

# This script generates a chroot tarball suitable for compiling
# Belenios. It uses mmdebstrap. On some machines, it runs in approx. 3
# min and generates a .tar.zst of approx. 1.5 GB.

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <target>"
    exit 1
fi

TARGET="$1"

. "$(dirname "$0")/config.sh"

export SOURCE_DATE_EPOCH="$(git log -1 --pretty=format:%ct)"

. "$(dirname "$0")/deps.sh"

TMP="$(mktemp --tmpdir --directory tmp.belenios.XXXXXXXXXX)"
trap "rm -rf $TMP" EXIT
chmod a+rx "$TMP"

cat > "$TMP/sources.list" <<EOF
deb $STABLE_MIRROR/debian $STABLE_SUITE main
EOF

mkdir "$TMP/belenios-npm"
( cd frontend && npm install && npm ci --cache "$TMP/belenios-npm" )
cp frontend/package-lock.json "$TMP/belenios-npm"
rm -rf "$TMP/belenios-npm/_logs"

echo "here1"

mmdebstrap --variant=buildd \
  --setup-hook='mkdir -p "$1"'"$TMP" \
  --include="passwd build-essential debhelper $BELENIOS_DEVDEPS $BELENIOS_DEBDEPS systemd-resolved" \
  --customize-hook='copy-in "'"$TMP"'"/belenios-npm /var/cache' \
  --customize-hook='chroot "$1" chown root:root -R /var/cache/belenios-npm' \
  --customize-hook='chroot "$1" apt-get update' \
  "$STABLE_SUITE" "$TARGET" "$TMP/sources.list"
