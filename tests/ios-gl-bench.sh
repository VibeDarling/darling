#!/bin/bash
# Runs ios-gl-bench under Darling on tools/pocket-host, prints its frame rate,
# and checks that the host shows its last GL frame with the label over it.
# See ios-gl-bench.md.
#
#   ios-gl-bench.sh POCKET_HOST APP [OUT_DIR]
#
# As ios-pocket-display.sh: `darling` must be on PATH or in $DARLING, and the
# host's socket is POCKET_SOCKET (/tmp/pocket.sock). SCREEN is the host's
# screen (720x1280@2); BENCH_SECONDS how long to count frames (5).
set -u
HOST=$1 APP=$2 OUT=${3:-out}
DARLING=${DARLING:-darling}
SOCKET=${POCKET_SOCKET:-/tmp/pocket.sock}
mkdir -p "$OUT"
failures=0

expect() { # condition name detail
	if [ "$1" = 1 ]; then echo "PASS $2${3:+: $3}"; else echo "FAIL $2${3:+: $3}"; failures=$((failures + 1)); fi
}

rm -f "$OUT/cmd"; mkfifo "$OUT/cmd"
"$HOST" "$SOCKET" "${SCREEN:-720x1280@2}" 48,0,32,0 < "$OUT/cmd" > "$OUT/host.out" 2>&1 &
HOST_PID=$!
exec 3> "$OUT/cmd"
for i in $(seq 1 50); do grep -q '^listening' "$OUT/host.out" && break; sleep 0.1; done

timeout 400 "$DARLING" shell env DARLING_POCKET_DISPLAY="$SOCKET" BENCH_SECONDS="${BENCH_SECONDS:-5}" ${BENCH_ENV:-} "$APP" > "$OUT/app.out" 2>&1 &
APP_PID=$!

for i in $(seq 1 300); do grep -q '^ready' "$OUT/app.out" && break; sleep 1; done
read -r _ _ GX GY _ RX RY _ WX WY < <(grep '^ready' "$OUT/app.out")
sleep 3

pixel() { # x y -> RRGGBB
	local before; before=$(grep -c '^pixel' "$OUT/host.out")
	echo "pixel $1 $2" >&3
	for i in $(seq 1 50); do [ "$(grep -c '^pixel' "$OUT/host.out")" -gt "$before" ] && break; sleep 0.1; done
	grep '^pixel' "$OUT/host.out" | tail -1 | cut -d' ' -f4
}

if [ -n "${GX:-}" ]; then
	G=$(pixel "$GX" "$GY"); R=$(pixel "$RX" "$RY"); W=$(pixel "$WX" "$WY")
	expect "$([ "$G" = 00ff00 ] && [ "$R" = ff0000 ] && echo 1)" "the host shows the last GL frame" "green $G, red $R"
	expect "$([ "$W" = ffffff ] && echo 1)" "with the label over it" "$W"
	echo "shot $OUT/ios-gl-bench.png" >&3; sleep 2
	echo "tap $GX $GY" >&3
else
	expect 0 "the app gets ready"
fi

wait $APP_PID
APP_STATUS=$?
grep -E 'frames in|pixels|OpenGLES: [0-9]* presents' "$OUT/app.out" | tail -4
echo quit >&3; exec 3>&-
wait $HOST_PID
[ $APP_STATUS = 0 ] || failures=$((failures + 1))
echo "$failures host failures, app exit $APP_STATUS"
exit $((failures != 0))
