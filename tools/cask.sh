#!/bin/sh
# The Homebrew casks a release updates in afrase/homebrew-tap, written from packaging/homebrew/nushi.rb (ADR 0055,
# ADR 0108): nushi follows the latest release; nushi@beta the newest version of all, a beta or the release that
# passed it. release.yml runs it.
#   tools/cask.sh which <tag> <the latest release's tag> [<the newest pre-release's tag>]
#       the casks the release <tag> updates, one a line; none for an older release or beta built again
#   tools/cask.sh write <cask> <version> <sha256>
#       that cask, on stdout
set -eu

# core is a tag's X.Y.Z: "v0.29.0-beta.1" is 0.29.0.
core() {
  v=${1#v}
  printf '%s' "${v%%-*}"
}

# newer says whether the X.Y.Z $1 is after $2.
newer() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "$1" ]
}

case "${1:-}" in
which)
  tag=$2 latest=$3 beta=${4:-}
  if [ "$tag" = "$latest" ]; then
    echo nushi
    # The beta cask moves on to the release, unless a beta of a later release is out already.
    if [ -z "$beta" ] || ! newer "$(core "$beta")" "$(core "$latest")"; then echo nushi@beta; fi
  elif [ -n "$beta" ] && [ "$tag" = "$beta" ] && newer "$(core "$tag")" "$(core "$latest")"; then
    echo nushi@beta
  fi
  ;;
write)
  cask=$2 version=$3 sha=$4
  case "$cask" in
  nushi) other=nushi@beta ;;
  nushi@beta) other=nushi ;;
  *)
    echo "cask.sh: no cask $cask" >&2
    exit 2
    ;;
  esac
  sed -e "s/@CASK@/$cask/" -e "s/@OTHER@/$other/" -e "s/@VERSION@/$version/" -e "s/@SHA256@/$sha/" \
    "$(dirname "$0")/../packaging/homebrew/nushi.rb"
  ;;
*)
  echo "usage: cask.sh which <tag> <latest> [<newest beta>] | write <cask> <version> <sha256>" >&2
  exit 2
  ;;
esac
