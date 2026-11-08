#!/bin/sh
# Builds the Linux app's package (ADR 0102) into app/build/linux/nushi, for
# this machine's architecture (Flutter doesn't cross-build): Flutter's
# release bundle (the binary nushi, lib/, data/) with nushid in lib/ (no
# cgo, ADR 0101), the .desktop file and icons under share/, and install.sh;
# then checks it (tools/check-bundle.sh). make package-linux runs it, and
# through that CI and tools/release.sh (the release's tarballs), so CI
# builds what a release ships.
# Usage: tools/package-linux.sh VERSION BUILD
set -eu
fail() { echo "package-linux: $*" >&2; exit 1; }
[ $# = 2 ] || fail "usage: tools/package-linux.sh VERSION BUILD"
version=$1
build=$2
[ "$(uname -s)" = Linux ] || fail "Linux only (make package on a Mac)"
case $(uname -m) in
x86_64) arch=x64 ;;
aarch64 | arm64) arch=arm64 ;;
*) fail "no Flutter build for $(uname -m)" ;;
esac
cd "$(dirname "$0")/.."
package=app/build/linux/nushi

# No make mermaid: Linux has no diagrams yet (its Native.diagrams is null,
# so a diagram's source shows), and mermaid.min.js would be 5 MB unused.
(cd app && flutter build linux --release --build-name "$version" --build-number "$build")
rm -rf "$package"
cp -R "app/build/linux/$arch/release/bundle" "$package"
CGO_ENABLED=0 go build -trimpath -ldflags "-X github.com/afrase/nushi/internal/api.Release=$version" \
  -o "$package/lib/nushid" ./cmd/nushid
mkdir -p "$package/share/applications" "$package/share/icons"
cp app/linux/packaging/com.nushihq.Nushi.desktop "$package/share/applications/"
cp -R app/linux/packaging/icons/hicolor "$package/share/icons/"
cp app/linux/packaging/install.sh "$package/"
tools/check-bundle.sh "$package"
