#!/bin/sh
# Builds mobilesubstrate.deb, the package that jailbreak tweaks depend on.
#
# Darling's Substrate is part of the system (/Library/Frameworks/
# CydiaSubstrate.framework and /usr/lib/substrate/SubstrateLoader.dylib),
# so this package holds no code: it tells dpkg that Substrate is there and
# links the rootless (/var/jb) paths that newer tweaks load it from.
#
# Install it inside Darling with: dpkg -i mobilesubstrate.deb

set -e

out=${1:-mobilesubstrate.deb}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/control" "$work/data/var/jb/Library/Frameworks" \
	"$work/data/var/jb/Library/MobileSubstrate/DynamicLibraries" \
	"$work/data/var/jb/usr/lib"
ln -s /Library/Frameworks/CydiaSubstrate.framework "$work/data/var/jb/Library/Frameworks/CydiaSubstrate.framework"
ln -s /usr/lib/libsubstrate.dylib "$work/data/var/jb/usr/lib/libsubstrate.dylib"
ln -s /usr/lib/substrate "$work/data/var/jb/usr/lib/substrate"

cat > "$work/control/control" <<EOF
Package: mobilesubstrate
Name: Cydia Substrate
Version: 0.9.8000+darling
Architecture: iphoneos-arm
Provides: cydia-substrate
Section: System
Priority: required
Maintainer: Darling developers
Description: tweak support for Darling
 Darling's own implementation of the Cydia Substrate API. Tweaks in
 /Library/MobileSubstrate/DynamicLibraries are loaded into the apps their
 filters name.
EOF

echo 2.0 > "$work/debian-binary"
tar -C "$work/control" --owner=0 --group=0 -czf "$work/control.tar.gz" .
tar -C "$work/data" --owner=0 --group=0 -czf "$work/data.tar.gz" .
rm -f "$out"
ar rc "$out" "$work/debian-binary" "$work/control.tar.gz" "$work/data.tar.gz"
