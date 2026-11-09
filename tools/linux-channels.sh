#!/bin/sh
# Runs app/integration_test/linux_channels_test.dart on Linux: the runner's
# own channels (app/linux/runner) against the real GTK and GIO (ADR 0104),
# on a virtual X display (xvfb-run) and a private session bus
# (dbus-run-session), with throwaway XDG folders whose only default apps are
# fakes that write down what they were given and which of Nushi's variables
# they got (NUSHI_DATA and NUSHI_PROBE are set here: an app must get none).
# Nothing on the machine opens, no xdg-open runs, and the app's data folder
# is throwaway too. Needs xvfb-run, dbus-run-session, xclip and flutter;
# extra arguments go to flutter test.
set -eu
fail() { echo "linux-channels: $*" >&2; exit 1; }
[ "$(uname -s)" = Linux ] || fail "Linux only"
for tool in xvfb-run dbus-run-session xclip flutter; do
  command -v "$tool" >/dev/null || fail "needs $tool"
done
app=$(cd "$(dirname "$0")/../app" && pwd)
probe=$(mktemp -d "${TMPDIR:-/tmp}/nushi-probe-XXXXXX")
trap 'rm -rf "$probe"' EXIT
mkdir -p "$probe/data/applications" "$probe/config" "$probe/share" \
  "$probe/services" "$probe/nushi"
# The system's GSettings schemas and MIME database, but none of its apps.
for d in glib-2.0 mime; do
  [ ! -d "/usr/share/$d" ] || ln -s "/usr/share/$d" "$probe/share/$d"
done
# A session bus that starts none of the system's services (a real file
# manager would answer for the test's fake one).
cat >"$probe/bus.conf" <<EOF
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=$probe</listen>
  <auth>EXTERNAL</auth>
  <servicedir>$probe/services</servicedir>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
EOF

cat >"$probe/record" <<'EOF'
#!/bin/sh
# A fake default app: writes down which of Nushi's variables it was
# started with (none, as it should be), then what it was given, a line a
# launch: the test waits for that line, so the variables are written first.
app=$1
shift
env | grep -E '^NUSHID?_' >>"$(dirname "$0")/environment-$app"
printf '%s\n' "$*" >>"$(dirname "$0")/launched-$app"
EOF
chmod +x "$probe/record"
# fake <name> <field code> <MIME types>: the fake app's desktop entry.
fake() {
  cat >"$probe/data/applications/nushi-fake-$1.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Nushi fake $1
Exec="$probe/record" $1 $2
MimeType=$3
NoDisplay=true
EOF
}
fake browser %u 'x-scheme-handler/http;x-scheme-handler/https;'
fake editor %f 'text/plain;'
fake files %u 'inode/directory;'
fake mail %u 'x-scheme-handler/mailto;'
cat >"$probe/config/mimeapps.list" <<EOF
[Default Applications]
x-scheme-handler/http=nushi-fake-browser.desktop
x-scheme-handler/https=nushi-fake-browser.desktop
text/plain=nushi-fake-editor.desktop
inode/directory=nushi-fake-files.desktop
x-scheme-handler/mailto=nushi-fake-mail.desktop
EOF

# Whether gdk-pixbuf decodes a picture here: where it decodes through
# glycin (Arch's), each picture goes to a loader in a bwrap sandbox, which
# a VM or container may not allow. The test of a picture that isn't PNG
# skips if not.
pixbuf=1
if [ -d /usr/lib/glycin-loaders ] &&
  ! bwrap --ro-bind /usr /usr --symlink usr/lib /lib64 true 2>/dev/null; then
  pixbuf=0
fi

cd "$app"
env -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS \
  GDK_BACKEND=x11 \
  XDG_DATA_HOME="$probe/data" \
  XDG_CONFIG_HOME="$probe/config" \
  XDG_DATA_DIRS="$probe/share" \
  NUSHI_DATA="$probe/nushi" \
  NUSHI_PROBE="$probe" \
  NUSHI_PROBE_PIXBUF=$pixbuf \
  NO_AT_BRIDGE=1 \
  dbus-run-session --config-file="$probe/bus.conf" -- \
  xvfb-run -a -s '-screen 0 1280x800x24' \
  flutter test integration_test/linux_channels_test.dart -d linux "$@"
