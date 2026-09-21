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
#   DARLING_QA_STAGE       optional. Which bundles to stage from it: a
#                          space-separated list, or "all" for every .app there.
#                          Default "TextEdit.app Stickies.app", the two the
#                          checklist names.
#   DARLING_VIEWER_IMAGE   optional. A built Darling image supplying the AppKit
#                          Wayland backend, which the installed runtime's own
#                          prefix may predate. Same variable build-standalone.py
#                          uses, so one image serves both.
#   DARLING_LAUNCHER       optional. Default /usr/local/bin/darling.
#
# The QA prefix is disposable and this script stages into it. To make that
# safe it refuses any prefix it did not initialize itself, identified by the
# marker below, so pointing it at a persistent prefix cannot overwrite one.
#
# Every run that reaches prefix initialization appends one JSON object to
# <prefix>.boot-log.jsonl. Container startup here fails intermittently, so a
# run that only recorded pass/fail could never tell one startup failure from
# another afterwards; the log keeps the exit status and the first line of
# stderr, which is what makes the failure modes distinguishable, plus whether
# the run was a cold boot. The log is observational only: it never changes what
# the script does, and a failed write is ignored.
set -euo pipefail

launcher=${DARLING_LAUNCHER:-/usr/local/bin/darling}
image=${DARLING_VIEWER_IMAGE:-}
output=${DARLING_VIEWER_OUTPUT:-}
prefix=${DARLING_QA_PREFIX:-$HOME/.darling-qa}
apps=${DARLING_QA_APPS:-${XDG_DATA_HOME:-$HOME/.local/share}/darling/macos-apps/Applications}
stage=${DARLING_QA_STAGE:-TextEdit.app Stickies.app}
marker=$prefix/.darling-qa-prefix
lock=$prefix.lock
# Sibling of the prefix, like the lock, so it is never mistaken for prefix
# content and cannot collide with the marker check.
boot_log=$prefix.boot-log.jsonl
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
binary_sha256=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["binary_sha256"])' \
	"$output/manifest.json" 2>/dev/null) || binary_sha256=

mkdir -p "$(dirname "$prefix")"
exec 9>"$lock"
flock -n 9 || die "The QA profile is already running."

# Checked after taking the lock, so the answer cannot go stale between the two.
# A free lock does not prove the runtime is free: a container started outside
# this protocol holds no lock, so ask the host directly.
python3 "${BASH_SOURCE[0]%/*}/qa-prefix-busy.py" "$prefix" ||
	die "A Darling container is already live on $prefix; refusing to stage into it."

boot_trial=false
container_armed=false
cold_boot=false
init_status=
init_message=
launch_status=

# Never let recording a run affect the run: a read-only path, a full disk or a
# broken python3 degrades to silence.
record_run() {
	python3 - "$boot_log" "$cold_boot" "${init_status:-}" "$init_message" \
		"$bundle" "$binary_sha256" "${launch_status:-}" "$1" <<-'PY' 2>/dev/null || true
		import datetime, json, sys
		path, cold, init, message, bundle, sha, launch, script = sys.argv[1:9]
		number = lambda v: int(v) if v != "" else None
		record = {
		    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
		    "cold_boot": cold == "true",
		    "init_exit": number(init),
		    "init_message": message,
		    "bundle": bundle,
		    "binary_sha256": sha,
		    "launch_exit": number(launch),
		    "script_exit": number(script),
		}
		with open(path, "a") as log:
		    log.write(json.dumps(record) + "\n")
	PY
}

on_exit() {
	local status=$?
	# Both the signal trap and the EXIT trap reach here, which would record one
	# run twice and corrupt the dataset the log exists to build.
	trap - EXIT INT TERM
	# Shut down only this prefix's container, never a broader cleanup.
	if [[ $container_armed == true ]]; then
		"$launcher" shutdown >/dev/null 2>&1 || true
	fi
	if [[ $boot_trial == true ]]; then
		record_run "$status"
	fi
}
trap on_exit EXIT INT TERM

export DPREFIX="$prefix"
[[ -e "$prefix" ]] || cold_boot=true
boot_trial=true
if [[ $cold_boot == true ]]; then
	# Let the installed launcher initialize an absent prefix itself; a
	# precreated directory would skip initialization. Its stderr is tee'd so
	# it still reaches the terminal live while being recorded.
	init_stderr=$(mktemp)
	set +e
	{ "$launcher" shell /usr/bin/true 2>&1 1>&3 3>&- | tee -a "$init_stderr" >&2; } 3>&1
	init_status=${PIPESTATUS[0]}
	set -e
	# The LAST non-empty line, not the first: a cold boot always opens with
	# the launcher's "Setting up a new Darling prefix" banner, which is
	# identical whether the boot then succeeds or times out. The failure
	# reason is the final line, and it is the only thing that makes one
	# startup failure distinguishable from another after the fact.
	init_message=$(awk 'NF { line = $0 } END { print line }' "$init_stderr" 2>/dev/null || true)
	rm -f "$init_stderr"
	[[ $init_status -eq 0 ]] || exit "$init_status"
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
if [[ "$stage" == all ]]; then
	mapfile -t staged < <(cd "$apps" 2>/dev/null && printf '%s\n' *.app)
	[[ ${#staged[@]} -gt 0 && ${staged[0]} != '*.app' ]] ||
		die "DARLING_QA_STAGE=all but no .app bundles found in $apps"
else
	read -r -a staged <<<"$stage"
fi
echo "Staging ${#staged[@]} application bundle(s) from $apps"
for app in "${staged[@]}"; do
	[[ -d "$apps/$app" ]] || die "Missing application bundle: $apps/$app"
	rm -rf -- "$prefix/Applications/$app"
	cp -a "$apps/$app" "$prefix/Applications/$app"
done
rm -rf -- "$prefix/Applications/Darling Applications.app"
cp -a "$bundle" "$prefix/Applications/Darling Applications.app"

# The prefix is initialized by the INSTALLED runtime, whose framework payload can
# predate the AppKit Wayland backend; without it the viewer launches with no
# surface and simply shows nothing. Stage the backend from the configured image,
# which is a built checkout and so attributable to a commit.
backends="$prefix/System/Library/Frameworks/AppKit.framework/Versions/C/Resources/Backends"
# Require the real bundle shape: the build tree also contains a same-named
# directory of generated protocol sources, which is not loadable and which
# AppKit reports only as "Cannot find executable for CFBundle".
backend_src="$image/build/src/external/cocotron/AppKit/Wayland.backend"
if [[ -n "$image" && -d "$backend_src/Contents/MacOS" ]]; then
	install -d "$backends"
	rm -rf -- "$backends/Wayland.backend"
	cp -a "$backend_src" "$backends/Wayland.backend"
fi
[[ -d "$backends/Wayland.backend/Contents/MacOS" ]] || die \
	"This prefix has no loadable AppKit Wayland backend, so the viewer would start with no window.
The prefix is initialized by the installed runtime, whose payload may predate it, and a plain
build tree does not emit the bundle layout: that comes from the install step. Provide one via a
DESTDIR install of the image, or point DARLING_QA_PREFIX at a prefix from a newer runtime." 

container_armed=true

echo "Launching the QA profile at $prefix"
echo "Bundle under test: $bundle"
# Run the viewer in the background and wait on it: bash defers traps until a
# foreground child exits, so Ctrl-C or a TERM would otherwise not shut the
# container down until the viewer had already quit by itself.
set +e
"$launcher" shell env -u DISPLAY \
	DARLING_DISABLE_PTRAUTH=1 \
	DARLING_APPKIT_BACKEND=wayland \
	WAYLAND_DISPLAY="$runtime_dir/$wayland_display" \
	XDG_RUNTIME_DIR="$runtime_dir" \
	"/Applications/Darling Applications.app/Contents/MacOS/Darling Applications" &
viewer=$!
wait "$viewer"
launch_status=$?
set -e
exit "$launch_status"
