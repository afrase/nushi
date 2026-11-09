#!/bin/sh
# Starts the Linux app as a user would and checks that it comes up (ADR
# 0104): a release tarball unpacked and installed by its install.sh into a
# throwaway home, then the installed app run on a virtual X display
# (xvfb-run) and a private session bus with no NUSHI_DATA, so it finds no
# daemon in its data folder (the home's ~/.local/share/nushi) and starts
# its own lib/nushid. It passes once nushid.log says the app connected,
# with that nushid running, and no error of the app's in nushid.log or
# app.log. SHOT=<file.png> also takes a screenshot (ImageMagick's import).
# Nothing of the machine opens (xdg-open and open are stubs first on PATH)
# and everything started is stopped, its folder removed. CI runs it on each
# architecture's package.
# Usage: tools/linux-smoke.sh nushi-X.Y.Z-linux-<arch>.tar.gz
set -eu
fail() { echo "linux-smoke: $*" >&2; exit 1; }
id=com.nushihq.Nushi

# Inside the display and the bus: the app started, watched until it
# connects, shot, and quit.
if [ -n "${NUSHI_SMOKE_HOME:-}" ]; then
  opt=$NUSHI_SMOKE_HOME/.local/opt/nushi
  data=$NUSHI_SMOKE_HOME/.local/share/nushi
  "$opt/nushi" >"$NUSHI_SMOKE_HOME/app.out" 2>&1 &
  app=$!
  trap 'kill "$app" 2>/dev/null || true' EXIT
  i=0
  until grep -q 'msg="app connected"' "$data/nushid.log" 2>/dev/null; do
    kill -0 "$app" 2>/dev/null || { cat "$NUSHI_SMOKE_HOME/app.out" >&2; fail "the app quit"; }
    i=$((i + 1))
    [ "$i" -lt 240 ] || { cat "$NUSHI_SMOKE_HOME/app.out" >&2; fail "the app didn't connect in 2 minutes"; }
    sleep 0.5
  done
  # A few frames after connecting, for the screenshot and any error.
  sleep 3
  [ -z "${SHOT:-}" ] || import -window root "$SHOT"
  exit 0
fi

[ $# = 1 ] && [ -f "$1" ] || fail "usage: tools/linux-smoke.sh nushi-X.Y.Z-linux-<arch>.tar.gz"
for tool in xvfb-run dbus-run-session pgrep; do
  command -v "$tool" >/dev/null || fail "needs $tool"
done
[ -z "${SHOT:-}" ] || command -v import >/dev/null || fail "SHOT needs ImageMagick's import"
# A short path: the daemon's socket is under it, and a socket's path has a
# length limit.
t=$(mktemp -d /tmp/nushi-smoke-XXXXXX)
home=$t/home
opt=$home/.local/opt/nushi
data=$home/.local/share/nushi
stop() {
  pkill -TERM -f "^$opt/lib/nushid" 2>/dev/null || true
  i=0
  while pgrep -f "^$opt/lib/nushid" >/dev/null && [ "$i" -lt 20 ]; do
    sleep 0.5
    i=$((i + 1))
  done
  pkill -KILL -f "^$opt/lib/nushid" 2>/dev/null || true
  rm -rf "$t"
}
trap stop EXIT
trap 'exit 1' INT TERM
mkdir -p "$home" "$t/stub" "$t/unpacked"
printf '#!/bin/sh\nexit 1\n' >"$t/stub/xdg-open"
cp "$t/stub/xdg-open" "$t/stub/open"
chmod +x "$t/stub/xdg-open" "$t/stub/open"

tar -xzf "$1" -C "$t/unpacked"
[ -x "$t/unpacked/nushi/install.sh" ] || fail "the tarball has no nushi/install.sh"
# The home's own XDG folders, and none of Nushi's variables: the app picks
# its data folder and starts its daemon as for a user.
nushi_vars=$(env | sed -n 's/^\(NUSHID\{0,1\}_[A-Za-z0-9_]*\)=.*/-u \1/p')
# shellcheck disable=SC2086 # nushi_vars is a list of env's options
set -- env $nushi_vars -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
  -u DBUS_SESSION_BUS_ADDRESS -u WAYLAND_DISPLAY -u DISPLAY \
  HOME="$home" PATH="$t/stub:$PATH" GDK_BACKEND=x11 NO_AT_BRIDGE=1
"$@" "$t/unpacked/nushi/install.sh"
grep -qx "Exec=\"$opt/nushi\"" "$home/.local/share/applications/$id.desktop" ||
  fail "install.sh's .desktop file doesn't name $opt/nushi"
[ -f "$home/.local/share/icons/hicolor/scalable/apps/$id.svg" ] || fail "install.sh installed no icon"

"$@" NUSHI_SMOKE_HOME="$home" SHOT="${SHOT:-}" dbus-run-session -- \
  xvfb-run -a -s '-screen 0 1700x1100x24' "$0"
# -login's shell replaced itself with the daemon, its command line the
# package's nushid alone.
pgrep -fx "$opt/lib/nushid" >/dev/null || fail "the app's daemon isn't the package's lib/nushid"
if grep 'level=ERROR' "$data/app.log" 2>/dev/null ||
  grep 'level=ERROR.*source=app' "$data/nushid.log"; then
  fail "the app logged an error"
fi
echo "linux-smoke: the app started its daemon and connected"
