#!/bin/bash
# Runs ios-pocket-display under Darling on tools/pocket-host, as a phone host
# would: it drives the app by touches and input method text, and checks what
# the host shows. See ios-pocket-display.md.
#
#   ios-pocket-display.sh POCKET_HOST APP [OUT_DIR]
#
# APP is the test's path inside the container; `darling` must be on PATH or
# in $DARLING. The host's socket is POCKET_SOCKET (/tmp/pocket.sock), and
# the app finds it at POCKET_APP_SOCKET: the same path, since a prefix's /tmp
# is the host's.
set -u
HOST=$1 APP=$2 OUT=${3:-out}
DARLING=${DARLING:-darling}
SOCKET=${POCKET_SOCKET:-/tmp/pocket.sock}
APP_SOCKET=${POCKET_APP_SOCKET:-$SOCKET}
mkdir -p "$OUT"
failures=0

expect() { # condition name detail
	if [ "$1" = 1 ]; then echo "PASS $2${3:+: $3}"; else echo "FAIL $2${3:+: $3}"; failures=$((failures + 1)); fi
}

rm -f "$OUT/cmd"; mkfifo "$OUT/cmd"
"$HOST" "$SOCKET" 720x1280@2 48,0,32,0 < "$OUT/cmd" > "$OUT/host.out" 2>&1 &
HOST_PID=$!
exec 3> "$OUT/cmd"
for i in $(seq 1 50); do grep -q '^listening' "$OUT/host.out" && break; sleep 0.1; done

timeout 400 "$DARLING" shell env DARLING_POCKET_DISPLAY="$APP_SOCKET" "$APP" > "$OUT/app.out" 2>&1 &
APP_PID=$!

for i in $(seq 1 300); do grep -q '^ready' "$OUT/app.out" && break; sleep 1; done
read -r _ _ BX BY _ P0X P0Y P1X P1Y _ FX FY _ GX GY _ LX LY _ WX WY < <(grep '^ready' "$OUT/app.out")
# The first frame can follow "ready".
for i in $(seq 1 60); do grep -q '^present' "$OUT/host.out" && break; sleep 1; done
sleep 2

pixel() { # x y -> RRGGBB
	local before; before=$(grep -c '^pixel' "$OUT/host.out")
	echo "pixel $1 $2" >&3
	for i in $(seq 1 50); do [ "$(grep -c '^pixel' "$OUT/host.out")" -gt "$before" ] && break; sleep 0.1; done
	grep '^pixel' "$OUT/host.out" | tail -1 | cut -d' ' -f4
}
wait_for() { # pattern seconds
	for i in $(seq 1 $(($2 * 10))); do grep -q "$1" "$OUT/host.out" && return 0; sleep 0.1; done
	return 1
}

expect "$(grep -q '^hello' "$OUT/host.out" && grep -q '^buffer .* 720 1280' "$OUT/host.out" && echo 1)" \
	"the app connects and gives the host a full-screen buffer at 2x" "$(grep -m1 '^buffer' "$OUT/host.out")"
G=$(pixel "$GX" "$GY"); L=$(pixel "$LX" "$LY"); W=$(pixel "$WX" "$WY")
expect "$([ "$G" = 00ff00 ] && [ "$L" = 0000ff ] && [ "$W" = ffffff ] && echo 1)" \
	"the host shows what the app drew, where it drew it" "green $G, blue $L, white $W"

echo "tap $BX $BY" >&3; sleep 2
echo "drag $P0X $P0Y $P1X $P1Y 10" >&3; sleep 2
echo "down 1 $P0X $P0Y" >&3; echo "down 2 $P1X $P1Y" >&3; sleep 0.5
echo "move 1 $((P0X + 20)) $P0Y" >&3; echo "move 2 $((P1X - 20)) $P1Y" >&3; sleep 0.5
echo "up 1 $((P0X + 20)) $P0Y" >&3; echo "up 2 $((P1X - 20)) $P1Y" >&3; sleep 2

echo "tap $FX $FY" >&3
wait_for '^keyboard 1' 20
expect "$(grep -q '^keyboard 1' "$OUT/host.out" && echo 1)" "editing a text field asks the host for its keyboard"
expect "$(grep -q '^keyboard 1 type 7 return 1 caps 1 correct 1 flags 0$' "$OUT/host.out" && echo 1)" \
	"of the kind the field's traits name" "$(grep -m1 '^keyboard 1' "$OUT/host.out")"
echo "ime 600" >&3; sleep 1
echo "text hello" >&3; sleep 1
echo "key 51" >&3; sleep 1
echo "shot $OUT/pocket-display.png" >&3; sleep 2
echo "key 36" >&3
wait_for '^keyboard 0' 20
expect "$(grep -q '^keyboard 0' "$OUT/host.out" && echo 1)" "and lets it go when editing ends"
echo "ime 0" >&3

wait $APP_PID
APP_STATUS=$?
grep -E '^(PASS|FAIL)' "$OUT/app.out"
echo quit >&3; exec 3>&-
wait $HOST_PID
[ $APP_STATUS = 0 ] || failures=$((failures + 1))
echo "$failures host failures, app exit $APP_STATUS"
exit $((failures != 0))
