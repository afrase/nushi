#!/bin/sh
# Checks a package of the app: a Mac's Nushi.app, or the Linux app's folder
# (tools/package-linux.sh), told apart by their shape.
# Usage: tools/check-bundle.sh <Nushi.app | the Linux package's folder>
set -eu
app=$1
fail() { echo "check-bundle: $*" >&2; exit 1; }

# The Linux package (ADR 0104): nushid in lib/ (the app's AppInstall and the
# daemon's own check of its package look there), of the version the app
# says it is; the .desktop file, icons and install.sh that install it; and
# the newest glibc any of its programs or libraries needs, printed, and
# with NUSHI_GLIBC set, no newer than that (what docs/install.md promises).
# No Mermaid: Linux has no diagrams yet.
linux() {
  [ -x "$app/nushi" ] || fail "no $app/nushi"
  [ -x "$app/lib/nushid" ] || fail "no $app/lib/nushid"
  json=$(cat "$app/data/flutter_assets/version.json" 2>/dev/null) || fail "no data/flutter_assets/version.json"
  version=$(printf '%s' "$json" | sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p')
  daemon=$("$app/lib/nushid" -version | cut -d ' ' -f 2)
  [ -n "$version" ] && [ "$daemon" = "$version" ] || fail "nushid is $daemon, the app $version"
  id=com.nushihq.Nushi
  desktop=$app/share/applications/$id.desktop
  grep -qx "Icon=$id" "$desktop" 2>/dev/null || fail "no $desktop naming its icon"
  grep -qx "StartupWMClass=$id" "$desktop" || fail "$desktop doesn't match the window"
  for icon in scalable/apps/$id.svg 256x256/apps/$id.png; do
    [ -f "$app/share/icons/hicolor/$icon" ] || fail "no icon $icon"
  done
  [ -x "$app/install.sh" ] || fail "no install.sh"
  glibc=$(find "$app" -type f -exec sh -c 'readelf -V --wide "$1" 2>/dev/null' sh {} \; |
    grep -o 'GLIBC_[0-9][0-9.]*' | sed 's/GLIBC_//' | sort -uV | tail -n 1)
  [ -n "$glibc" ] || fail "no ELF file names a glibc version (is readelf there?)"
  echo "check-bundle: needs glibc $glibc"
  if [ -n "${NUSHI_GLIBC:-}" ] && [ "$(printf '%s\n%s\n' "$glibc" "$NUSHI_GLIBC" | sort -V | tail -n 1)" != "$NUSHI_GLIBC" ]; then
    fail "glibc $glibc is newer than $NUSHI_GLIBC"
  fi
  echo "check-bundle: $app is laid out as Linux's package, version $version"
}

# The Mac's: the daemon's helper app where the app looks for it (ADR 0036),
# Mermaid among its assets, and every part signed.
mac() {
  helper="$app/Contents/Helpers/Nushi Daemon.app"
  key() { plutil -extract "$2" raw -o - "$1/Contents/Info.plist" 2>/dev/null || true; }
  [ -x "$helper/Contents/MacOS/nushid" ] || fail "no $helper/Contents/MacOS/nushid"
  [ ! -e "$app/Contents/MacOS/nushid" ] || fail "nushid still in Contents/MacOS"
  [ "$(key "$helper" CFBundleIdentifier)" = com.nushihq.Nushi.daemon ] || fail "helper's bundle id"
  [ "$(key "$helper" CFBundleExecutable)" = nushid ] || fail "helper's executable"
  [ "$(key "$helper" LSBackgroundOnly)" = true ] || fail "helper isn't background-only"
  [ -f "$helper/Contents/Resources/AppIcon.icns" ] || fail "helper has no icon"
  agent="$app/Contents/Library/LaunchAgents/com.nushihq.Nushi.daemon.plist"
  [ "$(plutil -extract BundleProgram raw -o - "$agent" 2>/dev/null)" = Contents/Resources/start-daemon ] || fail "no launch agent"
  [ -x "$app/Contents/Resources/start-daemon" ] || fail "no start-daemon"
  mermaid="$app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/mermaid"
  [ -f "$mermaid/mermaid.html" ] && [ -f "$mermaid/mermaid.min.js" ] || fail "no mermaid.html and mermaid.min.js (make mermaid)"
  for part in "$helper" "$app"; do
    codesign --verify --strict "$part" || fail "$part isn't signed"
  done
  codesign --verify --deep --strict "$app" || fail "a part isn't signed"
  echo "check-bundle: $app is laid out and signed"
}

if [ -f "$app/Contents/Info.plist" ]; then
  mac
elif [ -f "$app/data/flutter_assets/version.json" ] || [ -x "$app/nushi" ]; then
  linux
else
  fail "$app is neither a Nushi.app nor a Linux package"
fi
