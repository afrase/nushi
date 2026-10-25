#!/bin/sh
# Writes each adapter's package-lock.json again from its package.json
# (internal/<agent>/adapter), after its pinned version changed, and says
# what it downloads and takes on disk, for its Download and Disk. npm runs
# with settings and caches of its own, removed after.
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
touch "$tmp/npmrc"
export npm_config_userconfig="$tmp/npmrc" npm_config_globalconfig="$tmp/npmrc.global" npm_config_update_notifier=false
for dir in internal/claude/adapter internal/codex/adapter; do
	(cd "$dir" && npm install --package-lock-only --ignore-scripts --no-audit --no-fund --cache "$tmp/cache" >/dev/null)
	mkdir "$tmp/i"
	cp "$dir"/package.json "$dir"/package-lock.json "$tmp/i/"
	(cd "$tmp/i" && npm ci --omit=optional --omit=dev --ignore-scripts --no-audit --no-fund --cache "$tmp/c" >/dev/null)
	down=$(find "$tmp/c/_cacache/content-v2" -type f -exec stat -f %z {} + | awk '{s += $1} END {print s}')
	disk=$(du -sk "$tmp/i/node_modules" | awk '{print $1 * 1024}')
	echo "$dir: Download $down, Disk $disk"
	rm -rf "$tmp/i" "$tmp/c"
done
