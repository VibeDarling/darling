#!/usr/bin/env bash
# Launch the Applications viewer in a disposable QA prefix on native Wayland.
#
# The bundle under test is whatever build-standalone.py last emitted: this
# script reads that build's manifest.json and verifies the bundle still matches
# it, rather than pinning hashes of one machine's build.
#
#   DARLING_VIEWER_OUTPUT  required. The build-standalone.py output directory,
#                          the one containing manifest.json.
#   DARLING_QA_PREFIX      optional. Disposable prefix. Default ~/.darling-qa.
#   DARLING_QA_APPS        optional. Directory holding the .app bundles staged
#                          for the checklist. Default
#                          $XDG_DATA_HOME/darling/macos-apps/Applications.
#   DARLING_LAUNCHER       optional. Default /usr/local/bin/darling.
#
# The QA prefix is disposable and this script stages into it. To make that
# safe it refuses any prefix it did not initialize itself, identified by the
# marker below, so pointing it at a persistent prefix cannot overwrite one.
set -euo pipefail

launcher=${DARLING_LAUNCHER:-/usr/local/bin/darling}
output=${DARLING_VIEWER_OUTPUT:-}
prefix=${DARLING_QA_PREFIX:-$HOME/.darling-qa}
apps=${DARLING_QA_APPS:-${XDG_DATA_HOME:-$HOME/.local/share}/darling/macos-apps/Applications}
marker=$prefix/.darling-qa-prefix
lock=$prefix.lock
runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
wayland_display=${WAYLAND_DISPLAY:-}

die() { echo "$*" >&2; exit 1; }

[[ -n "$output" ]] || die "DARLING_VIEWER_OUTPUT must be set to the build-standalone.py output directory."
[[ -x "$launcher" ]] || die "Darling launcher not found or not executable: $launcher"
[[ -n "$wayland_display" && -S "$runtime_dir/$wayland_display" ]] ||
	die "Run this from a Wayland session; WAYLAND_DISPLAY is unavailable."

# Resolve the bundle from the build manifest and confirm it still matches the
# hashes that build recorded. This replaces hashes pinned in the source tree,
# which went stale against every rebuild.
bundle=$(python3 "${BASH_SOURCE[0]%/*}/qa-verify-bundle.py" "$output") ||
	die "Viewer bundle does not match its build manifest; rebuild with build-standalone.py."

mkdir -p "$(dirname "$prefix")"
exec 9>"$lock"
flock -n 9 || die "The QA profile is already running."

# Checked after taking the lock, so the answer cannot go stale between the two.
# A free lock does not prove the runtime is free: a container started outside
# this protocol holds no lock, so ask the host directly.
python3 "${BASH_SOURCE[0]%/*}/qa-prefix-busy.py" "$prefix" ||
	die "A Darling container is already live on $prefix; refusing to stage into it."

export DPREFIX="$prefix"
if [[ ! -e "$prefix" ]]; then
	# Let the installed launcher initialize an absent prefix itself; a
	# precreated directory would skip initialization.
	"$launcher" shell /usr/bin/true
	[[ -f "$prefix/private/etc/passwd" ]] ||
		die "Prefix initialization did not produce a usable prefix at $prefix"
	touch "$marker"
elif [[ ! -f "$prefix/private/etc/passwd" ]]; then
	die "Refusing to use a partial or non-Darling prefix: $prefix"
elif [[ ! -f "$marker" ]]; then
	die "$prefix is not a QA prefix created by this script; refusing to stage into it."
fi
"$launcher" shutdown

install -d "$prefix/Applications"
for app in TextEdit.app Stickies.app; do
	[[ -d "$apps/$app" ]] || die "Missing application bundle for the checklist: $apps/$app"
	rm -rf -- "$prefix/Applications/$app"
	cp -a "$apps/$app" "$prefix/Applications/$app"
done
rm -rf -- "$prefix/Applications/Darling Applications.app"
cp -a "$bundle" "$prefix/Applications/Darling Applications.app"

# Shut down only this prefix's container, never a broader cleanup.
cleanup() { "$launcher" shutdown >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

echo "Launching the QA profile at $prefix"
echo "Bundle under test: $bundle"
"$launcher" shell env -u DISPLAY \
	DARLING_DISABLE_PTRAUTH=1 \
	DARLING_APPKIT_BACKEND=wayland \
	WAYLAND_DISPLAY="$runtime_dir/$wayland_display" \
	XDG_RUNTIME_DIR="$runtime_dir" \
	"/Applications/Darling Applications.app/Contents/MacOS/Darling Applications"
