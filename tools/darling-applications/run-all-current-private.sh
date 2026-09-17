#!/usr/bin/env bash
set -euo pipefail

launcher=/usr/local/bin/darling
prefix=/home/cristi/.darling-all-current-test
lock=/home/cristi/.darling-all-current-test.lock
viewer="/home/cristi/build/darling-all-current-20260917/viewer/Darling Applications.app"
frameworks=/home/cristi/build/darling-all-current-20260917/frameworks
frozen=/home/cristi/src/darling/build/codex-m4-integration
apps=/home/cristi/.local/share/darling/macos-apps/Applications
runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
wayland_display=${WAYLAND_DISPLAY:-}

[[ -n "$wayland_display" && -S "$runtime_dir/$wayland_display" ]] || {
  echo "Run this command from your Wayland desktop session (WAYLAND_DISPLAY is unavailable)." >&2
  exit 1
}

sha256sum -c <<'EOF'
296606924be73aba95500840958ad595734f7d411f2b47595693e6db7f6bbf8e  /home/cristi/build/darling-all-current-20260917/viewer/Darling Applications.app/Contents/MacOS/Darling Applications
375540fe9ceda267985633726403463744f2830015ab716de7b8bc7b10aa88bd  /home/cristi/build/darling-all-current-20260917/frameworks/AppKit
e1226c5a90a7ba8335dfa7e80586e68cbf218f6fe63ced335da6069402f0086b  /home/cristi/src/darling/build/codex-m4-integration/OpenGL
4bb6e4839a8f407874058029e58424899e694f210134463552d3cda29cc18780  /home/cristi/src/darling/build/codex-m4-integration/QuartzCore
c3a9db82009cfbee64a189e741c1af17fa903a8e73491a8f26c2d0422bc39913  /home/cristi/src/darling/build/codex-m4-integration/Wayland.backend/Contents/MacOS/Wayland
EOF

exec 9>"$lock"
flock -n 9 || { echo "The all-current test profile is already running." >&2; exit 1; }

export DPREFIX="$prefix"
if [[ ! -e "$prefix" ]]; then
  "$launcher" shell /usr/bin/true
elif [[ ! -f "$prefix/private/etc/passwd" ]]; then
  echo "Refusing to use a partial/non-Darling test prefix: $prefix" >&2
  exit 1
fi
"$launcher" shutdown

install -d "$prefix/Applications"
for app in TextEdit.app Stickies.app; do
  [[ -d "$apps/$app" ]] || { echo "Missing verified local app bundle: $apps/$app" >&2; exit 1; }
  rm -rf "$prefix/Applications/$app"
  cp -a "$apps/$app" "$prefix/Applications/$app"
done
rm -rf "$prefix/Applications/Darling Applications.app"
cp -a "$viewer" "$prefix/Applications/Darling Applications.app"

backend="$prefix/System/Library/Frameworks/AppKit.framework/Versions/C/Resources/Backends/Wayland.backend"
rm -rf "$backend"
install -d "$(dirname "$backend")"
cp -a "$frozen/Wayland.backend" "$backend"
for spec in AppKit:C OpenGL:A QuartzCore:A; do
  name=${spec%%:*}; version=${spec##*:}
  target="$prefix/System/Library/Frameworks/$name.framework/Versions/$version/$name"
  install -d "$(dirname "$target")"
  if [[ "$name" == AppKit ]]; then cp "$frameworks/AppKit" "$target"; else cp "$frozen/$name" "$target"; fi
done

cleanup() { "$launcher" shutdown >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

echo "Launching the all-current private profile at $prefix"
"$launcher" shell env -u DISPLAY \
  DARLING_DISABLE_PTRAUTH=1 \
  DARLING_APPKIT_BACKEND=wayland \
  WAYLAND_DISPLAY="$runtime_dir/$wayland_display" \
  XDG_RUNTIME_DIR="$runtime_dir" \
  "/Applications/Darling Applications.app/Contents/MacOS/Darling Applications"
