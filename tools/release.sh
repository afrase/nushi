#!/bin/sh
# Builds a release's files into dist/ (ADR 0055), as the release workflow
# does, so it can be tried here: Nushi-X.Y.Z.zip (make package, ad hoc
# signed unless NUSHI_SIGN names an identity), nushi-relay-X.Y.Z-<os>-<arch>.tar.gz
# for the Pi and a Linux box (one static binary with the phone's web app,
# make web's, built in: ADR 0113), nushi-X.Y.Z-linux-<arch>.tar.gz
# (make package-linux, the Linux app under nushi/, for this machine's
# architecture: Flutter doesn't cross-build), and a .sha256 beside each.
# Usage: tools/release.sh X.Y.Z[-suffix] [app] [relay] [linux]
# Without parts, those this machine builds: app and relay on a Mac, relay
# and linux on Linux. The workflow builds each in a job of its own (the
# app on macOS, the rest on Linux, the Linux app on each architecture).
set -eu
version=${1:-}
if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'; then
  echo "usage: tools/release.sh X.Y.Z[-suffix] [app] [relay] [linux]" >&2
  exit 2
fi
shift
if [ "$(uname -s)" = Linux ]; then
  parts=${*:-relay linux}
else
  parts=${*:-app relay}
fi
for part in $parts; do
  case $part in
  app | relay | linux) ;;
  *)
    echo "tools/release.sh: no part $part (app, relay, linux)" >&2
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
    # The web app goes into the folder the relay embeds (cmd/nushi-relay/web,
    # which the repository keeps empty), for these builds only.
    make web
    git clean -qfdx cmd/nushi-relay/web
    cp -R app/build/web/. cmd/nushi-relay/web/
    test -f cmd/nushi-relay/web/index.html
    for target in linux/arm64 linux/amd64; do
      os=${target%/*}
      arch=${target#*/}
      out=dist/relay-$os-$arch
      mkdir "$out"
      CGO_ENABLED=0 GOOS=$os GOARCH=$arch go build -trimpath -ldflags "-s -w -X main.version=$version" \
        -o "$out/nushi-relay" ./cmd/nushi-relay
      tgz "dist/nushi-relay-$version-$os-$arch.tar.gz" -C "$out" nushi-relay
      rm -rf "$out"
    done
    git clean -qfdx cmd/nushi-relay/web
    ;;
  linux)
    make package-linux NUSHI_VERSION="$version"
    tgz "dist/nushi-$version-linux-$(go env GOARCH).tar.gz" -C app/build/linux nushi
    ;;
  esac
done

cd dist
for f in *; do
  shasum -a 256 "$f" >"$f.sha256"
done
ls -l
