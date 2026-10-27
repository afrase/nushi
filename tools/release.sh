#!/bin/sh
# Builds a release's files into dist/ (ADR 0055), as the release workflow
# does, so it can be tried here: Nushi-X.Y.Z.zip (make package, ad hoc
# signed unless NUSHI_SIGN names an identity), nushi-relay-X.Y.Z-<os>-<arch>.tar.gz
# for the Pi, a Linux box and a Mac, nushi-web-X.Y.Z.tar.gz (make web,
# the phone's web app, under nushi-web/), and a .sha256 beside each.
# Usage: tools/release.sh X.Y.Z[-suffix] [app] [relay] [web]
# Without parts, all three; the workflow builds each in a job of its own
# (the app on macOS, the relays and the web app on Linux).
set -eu
version=${1:-}
if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'; then
  echo "usage: tools/release.sh X.Y.Z[-suffix] [app] [relay] [web]" >&2
  exit 2
fi
shift
parts=${*:-app relay web}
for part in $parts; do
  case $part in
  app | relay | web) ;;
  *)
    echo "tools/release.sh: no part $part (app, relay, web)" >&2
    exit 2
    ;;
  esac
done
cd "$(dirname "$0")/.."
# Tarballs owned by root, without macOS's metadata: unpacked as root on a
# Pi, the files are root's, not the building account's uid. GNU tar (Linux)
# and bsdtar (macOS) say it differently.
tgz() {
  if tar --version 2>/dev/null | grep -q GNU; then
    tar --owner=root:0 --group=root:0 -czf "$@"
  else
    tar --uid 0 --gid 0 --uname root --gname root --no-mac-metadata -czf "$@"
  fi
}
rm -rf dist
mkdir dist

for part in $parts; do
  case $part in
  app)
    make package NUSHI_VERSION="$version" NUSHI_SIGN="${NUSHI_SIGN:--}"
    ditto -c -k --keepParent app/build/macos/Build/Products/Release/Nushi.app "dist/Nushi-$version.zip"
    ;;
  relay)
    for target in linux/arm64 linux/amd64 darwin/arm64; do
      os=${target%/*}
      arch=${target#*/}
      out=dist/relay-$os-$arch
      mkdir "$out"
      CGO_ENABLED=0 GOOS=$os GOARCH=$arch go build -trimpath -ldflags "-s -w -X main.version=$version" \
        -o "$out/nushi-relay" ./cmd/nushi-relay
      tgz "dist/nushi-relay-$version-$os-$arch.tar.gz" -C "$out" nushi-relay
      rm -rf "$out"
    done
    ;;
  web)
    make web
    rm -rf dist/nushi-web
    cp -R app/build/web dist/nushi-web
    tgz "dist/nushi-web-$version.tar.gz" -C dist nushi-web
    rm -rf dist/nushi-web
    ;;
  esac
done

cd dist
for f in *; do
  shasum -a 256 "$f" >"$f.sha256"
done
ls -l
