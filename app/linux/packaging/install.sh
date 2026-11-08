#!/bin/sh
# Installs this Nushi for the user who runs it (ADR 0102), as make install
# does: the package to ~/.local/opt/nushi (replacing one there), its
# .desktop file, its Exec naming the package there, to
# $XDG_DATA_HOME/applications, and its icons to $XDG_DATA_HOME/icons/hicolor
# ($XDG_DATA_HOME when it's an absolute path, else ~/.local/share). Nothing
# outside the home folder, no root. With --uninstall, from the installed
# package, it removes those and Start at login's entry; chats' data stays
# in the data folder.
# Usage: install.sh [--uninstall]
set -eu
id=com.nushihq.Nushi
here=$(cd "$(dirname "$0")" && pwd)
opt=$HOME/.local/opt/nushi
case ${XDG_DATA_HOME:-} in
/*) share=$XDG_DATA_HOME ;;
*) share=$HOME/.local/share ;;
esac
case ${XDG_CONFIG_HOME:-} in
/*) config=$XDG_CONFIG_HOME ;;
*) config=$HOME/.config ;;
esac
desktop=$share/applications/$id.desktop
fail() { echo "install.sh: $*" >&2; exit 1; }

case ${1:-} in
--uninstall)
  # Start at login's entry (login_item_linux.dart) only if it starts this
  # package's daemon: another copy's is the user's.
  autostart=$config/autostart/$id.daemon.desktop
  if [ -f "$autostart" ] && grep -qF "$opt/lib/nushid" "$autostart"; then
    rm -f "$autostart"
  fi
  rm -f "$desktop" "$share"/icons/hicolor/*/apps/"$id".png "$share"/icons/hicolor/*/apps/"$id".svg
  rm -rf "$opt"
  echo "Nushi is uninstalled. Its data stays in ${share}/nushi."
  exit 0
  ;;
'') ;;
*) fail "usage: install.sh [--uninstall]" ;;
esac

[ -x "$here/nushi" ] && [ -x "$here/lib/nushid" ] || fail "run it from the unpacked nushi folder"
# GLib looks for a desktop entry's program before it undoes the spec's %%,
# so a path with % (or a control character) can't be written.
case $opt in
*%* | *[[:cntrl:]]*) fail "can't install under $opt: it has % or a control character" ;;
esac

# The package beside the old one, then swapped, so the old one's daemon
# sees its lib/nushid gone only for a moment, as an upgrade (ADR 0055).
if [ "$here" != "$opt" ]; then
  mkdir -p "$(dirname "$opt")"
  rm -rf "$opt.new"
  cp -Rp "$here" "$opt.new"
  rm -rf "$opt"
  mv "$opt.new" "$opt"
fi

# The Exec value (the desktop entry spec): the program quoted, with ", `, $
# and \ escaped, then every \ doubled for the value's own escapes.
exec=\"$(printf '%s' "$opt/nushi" | sed -e 's/[\\"`$]/\\&/g' -e 's/\\/\\\\/g')\"
mkdir -p "$share/applications" "$share/icons/hicolor"
EXEC=$exec awk '/^Exec=/ { print "Exec=" ENVIRON["EXEC"]; next } { print }' \
  "$opt/share/applications/$id.desktop" >"$desktop.new"
chmod 644 "$desktop.new"
mv "$desktop.new" "$desktop"
cp -R "$opt/share/icons/hicolor/." "$share/icons/hicolor/"
# GTK reads an icon folder again when its time changes.
touch "$share/icons/hicolor"
echo "Nushi is installed in $opt: open it from your applications."
