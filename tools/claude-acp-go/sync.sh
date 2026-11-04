#!/bin/sh
# Copies Nushi's Claude library into its own repository, github.com/afrase/claude-acp-go
# (default ~/Developer/claude-acp-go, or the folder given), so the two stay the same code apart from
# the import path: make claude-acp-go runs it.
#
# claudeagent/ and claudeacp/ replace the repository's copies whole (NOTICE files and testdata
# included); tools/claude-acp-go/repo/ holds the repository's own files (README, CHANGELOG, CI,
# lint config, cmd/claude-acp) and Nushi's LICENSE is its LICENSE. Every Go file's
# github.com/afrase/nushi/ becomes github.com/afrase/claude-acp-go/, and go.mod is written with
# Nushi's Go version and acp-go's, then tidied. It commits nothing: the repository's git is left
# for a look at the diff.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
dest=${1:-$HOME/Developer/claude-acp-go}
module=github.com/afrase/claude-acp-go
mkdir -p "$dest"
dest=$(cd "$dest" && pwd)
case "$dest" in "$root" | "$root"/*) echo "sync.sh: $dest is inside Nushi's tree" >&2; exit 2 ;; esac

for pkg in claudeagent claudeacp; do
	rsync -a --delete --exclude .DS_Store "$root/$pkg/" "$dest/$pkg/"
done
rsync -a --exclude .DS_Store "$root/tools/claude-acp-go/repo/" "$dest/"
cp "$root/LICENSE" "$dest/LICENSE"

find "$dest/claudeagent" "$dest/claudeacp" "$dest/cmd" -name '*.go' -exec \
	perl -pi -e "s#github\.com/afrase/nushi/#$module/#g" {} +

go_version=$(awk '$1 == "go" { print $2; exit }' "$root/go.mod")
acp_version=$(cd "$root" && go list -m -f '{{.Version}}' github.com/afrase/acp-go)
cat >"$dest/go.mod" <<EOF
module $module

go $go_version

require github.com/afrase/acp-go $acp_version
EOF
(cd "$dest" && GOWORK=off GOFLAGS=-mod=mod go mod tidy)

if grep -rn 'afrase/nushi' "$dest" --include='*.go' --include='go.mod' >/dev/null; then
	echo "sync.sh: Nushi's import path is left in:" >&2
	grep -rln 'afrase/nushi' "$dest" --include='*.go' --include='go.mod' >&2
	exit 1
fi
echo "synced into $dest"
