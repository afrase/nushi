#!/bin/sh
# Checks a packaged Nushi.app: the daemon's helper app where the app
# looks for it (ADR 0036), and every part signed.
set -eu
app=$1
helper="$app/Contents/Helpers/Nushi Daemon.app"
fail() { echo "check-bundle: $*" >&2; exit 1; }
key() { plutil -extract "$2" raw -o - "$1/Contents/Info.plist" 2>/dev/null || true; }

[ -x "$helper/Contents/MacOS/nushid" ] || fail "no $helper/Contents/MacOS/nushid"
[ ! -e "$app/Contents/MacOS/nushid" ] || fail "nushid still in Contents/MacOS"
[ "$(key "$helper" CFBundleIdentifier)" = com.nushihq.Nushi.daemon ] || fail "helper's bundle id"
[ "$(key "$helper" CFBundleExecutable)" = nushid ] || fail "helper's executable"
[ "$(key "$helper" LSBackgroundOnly)" = true ] || fail "helper isn't background-only"
[ -f "$helper/Contents/Resources/AppIcon.icns" ] || fail "helper has no icon"
for part in "$helper" "$app"; do
  codesign --verify --strict "$part" || fail "$part isn't signed"
done
codesign --verify --deep --strict "$app" || fail "a part isn't signed"
echo "check-bundle: $app is laid out and signed"
