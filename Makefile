# Dart's protoc plugins (make gen-tools), from pub's global bin.
export PATH := $(HOME)/.pub-cache/bin:$(PATH)
BUF := go run github.com/bufbuild/buf/cmd/buf@v1.75.0
# golangci-lint and govulncheck, pinned in their own module so the daemon's
# go.mod doesn't take their dependencies; built into bin/ (go tool -modfile
# can't run beside a go.work).
GOLANGCI := bin/golangci-lint
GOVULNCHECK := bin/govulncheck
DART_DIRS := app packages/uds_transport packages/noise packages/remote_transport packages/markdown packages/svg_path
# The machine make runs on: Darwin, or Linux (ADR 0101, 0104).
OS := $(shell uname -s)
# NUSHI_DATA=<folder> runs a second daemon and app beside the usual ones;
# else the daemon's own folder (on Linux $XDG_DATA_HOME/nushi when it's an
# absolute path, else ~/.local/share/nushi, as nushid picks it).
ifeq ($(OS),Linux)
DATA := $(or $(NUSHI_DATA),$(if $(filter /%,$(XDG_DATA_HOME)),$(XDG_DATA_HOME),$(HOME)/.local/share)/nushi)
else
DATA := $(or $(NUSHI_DATA),$(HOME)/Library/Application Support/Nushi)
endif
# Whether the tests in Chrome run: on the Mac always (Flutter and dart test
# find its Chrome); on Linux when CHROME_EXECUTABLE names one, or
# google-chrome is on PATH, which they find there.
CHROME := $(if $(filter Linux,$(OS)),$(or $(CHROME_EXECUTABLE),$(shell command -v google-chrome 2>/dev/null)),yes)
RELEASE := app/build/macos/Build/Products/Release/Nushi.app
HELPER := $(RELEASE)/Contents/Helpers/Nushi Daemon.app
# local.mk (not committed) holds this machine's own settings (CLAUDE_SCHEMAS).
-include local.mk
# The identity package signs with: NUSHI_SIGN, else the first Apple Development
# certificate in the keychain (Xcode › Settings › Accounts › Manage
# Certificates), else ad hoc ("-"). A real identity keeps the app the same app
# to macOS across builds, so the keychain asks once, not after every install.
SIGN := $(or $(NUSHI_SIGN),$(shell security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"'),-)
# The version package stamps into the app, its helper and the daemon:
# NUSHI_VERSION (a release's, from its tag: tools/release.sh), else the
# newest vX.Y.Z tag's, else 0.1.0; the build number is the commit count.
VERSION := $(or $(NUSHI_VERSION),$(patsubst v%,%,$(shell git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null)),0.1.0)
BUILD := $(or $(shell git rev-list --count HEAD 2>/dev/null),1)
# The oldest macOS Nushi runs on: Go 1.27's minimum, and SMAppService's
# (Start at login). The daemon is built for it too: cgo's clang would take
# the building Mac's SDK (flags rather than MACOSX_DEPLOYMENT_TARGET,
# which Go's build cache doesn't key on).
MACOS_MIN := 13.0
MACOS_CGO := -O2 -g -mmacosx-version-min=$(MACOS_MIN)

# Bare make only lists the targets: it starts nothing, so a tool that
# reads the Makefile with make -p (which runs the default target) can't
# start the daemon and the app on the real data folder. make run does.
.DEFAULT_GOAL := help

.PHONY: help run daemon stop app package package-linux install gen gen-tools test-go test-packages test-app test-timings test-web lint lint-go lint-dart lint-linux lint-windows check golden-diff renders lines relay relay-web icons adapters web web-fonts web-cut mermaid screenshots gallery claude-record

help:
	@echo "make run starts the daemon and the app; make check runs every check. Targets:"
	@sed -n 's/^\([a-z][a-z0-9-]*\):.*/\1/p' Makefile | sort -u | tr '\n' ' '; echo

# Starts the daemon in the background (unless one is running), then the app.
run: daemon app

daemon:
	go build -o bin/nushid ./cmd/nushid
	mkdir -p "$(DATA)"
	bin/nushid >>"$(DATA)/nushid.log" 2>&1 &

# Stops the daemon listening in $(DATA), not any other: on Linux through
# psmisc's fuser, which finds a Unix socket's holder by its path.
stop:
ifeq ($(OS),Linux)
	fuser -k -TERM "$(DATA)/nushid.sock" 2>/dev/null || true
else
	lsof -a -c nushid -t "$(DATA)/nushid.sock" | xargs kill 2>/dev/null || true
endif

app: mermaid
	cd app && flutter run -d $(if $(filter Linux,$(OS)),linux,macos)

# mermaid.min.js into the app's assets (the Mac app's and the phone's), as
# tools/mermaid/mermaid.lock pins it: fetched once into a cache outside the
# repository and checked. A new release: go run ./tools/mermaid -lock X.Y.Z.
mermaid:
	go run ./tools/mermaid

# A release app with nushid inside, in a background-only helper app
# (ADR 0036), signed with $(SIGN). The app starts it when no daemon is running,
# and launchd at login through start-daemon when Start at login is on.
package: mermaid
	cd app && flutter build macos --release --build-name "$(firstword $(subst -, ,$(VERSION)))" --build-number "$(BUILD)"
	rm -rf "$(RELEASE)/Contents/MacOS/nushid" "$(RELEASE)/Contents/Helpers"
	mkdir -p "$(HELPER)/Contents/MacOS" "$(HELPER)/Contents/Resources"
	CGO_CFLAGS="$(MACOS_CGO)" CGO_LDFLAGS="$(MACOS_CGO)" go build -ldflags "-X github.com/afrase/nushi/internal/api.Release=$(VERSION)" -o "$(HELPER)/Contents/MacOS/nushid" ./cmd/nushid
	cp app/macos/Daemon/Info.plist "$(HELPER)/Contents/"
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" "$(RELEASE)/Contents/Info.plist"
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" "$(HELPER)/Contents/Info.plist"
	plutil -replace CFBundleVersion -string "$(BUILD)" "$(HELPER)/Contents/Info.plist"
	cp "$(RELEASE)/Contents/Resources/AppIcon.icns" "$(HELPER)/Contents/Resources/"
	mkdir -p "$(RELEASE)/Contents/Library/LaunchAgents"
	cp app/macos/Daemon/com.nushihq.Nushi.daemon.plist "$(RELEASE)/Contents/Library/LaunchAgents/"
	cp app/macos/Daemon/start-daemon "$(RELEASE)/Contents/Resources/"
	codesign --force --timestamp=none --sign "$(SIGN)" "$(HELPER)"
	codesign --force --deep --timestamp=none --sign "$(SIGN)" "$(RELEASE)"
	tools/check-bundle.sh "$(RELEASE)"

# Linux's package (ADR 0104), app/build/linux/nushi: Flutter's release
# bundle with nushid in lib/, its .desktop file, icons and install.sh,
# checked; what a release's Linux tarball holds (tools/package-linux.sh).
package-linux:
	tools/package-linux.sh "$(VERSION)" "$(BUILD)"

# On Linux the package into ~/.local/opt/nushi, with its .desktop file
# and icons, through the install.sh it ships.
ifeq ($(OS),Linux)
install: package-linux
	app/build/linux/nushi/install.sh
else
install: package
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(HOME)/Applications/Nushi.app"
	ditto "$(RELEASE)" "$(HOME)/Applications/Nushi.app"
endif

# The relay (ADR 0033), one static binary: bin/nushi-relay -h lists its flags.
relay:
	CGO_ENABLED=0 go build -o bin/nushi-relay ./cmd/nushi-relay

# The relay with the phone's web app built in, as a release's is (ADR
# 0113): bin/nushi-relay -origin <address> serves it. The app goes into the
# folder the relay embeds for the build only.
relay-web: web
	git clean -qfdx cmd/nushi-relay/web
	cp -R app/build/web/. cmd/nushi-relay/web/
	CGO_ENABLED=0 go build -o bin/nushi-relay ./cmd/nushi-relay
	git clean -qfdx cmd/nushi-relay/web

# The phone's web app (ADR 0052), built into a release's relay or served
# from its folder by the relay's -web: app/build/web.
# The engine's fallback fonts come once from Google's font host into a
# cache outside the repository, checked against tools/webbuild/fonts.lock.
FLUTTER_WEB = cd app && flutter build web -t lib/phone_main.dart --release --no-web-resources-cdn --no-wasm-dry-run --no-source-maps
web: mermaid
	rm -rf app/build/web
	$(FLUTTER_WEB)
	go run ./tools/webbuild app/build/web

# The web app's IBM Plex Sans cut to Latin and the punctuation and symbols
# the app uses, its width fixed and its hinting dropped (0.5 MB less at
# start; the engine's fallback fonts draw the rest): after app/fonts
# changes (make web stops). JetBrains Mono keeps every character, as a
# fallback font would leave code's grid, and loses its hinting and its
# ligatures, which theme.code turns off (79 to 54 KB with Brotli). Needs
# HarfBuzz's hb-subset (brew install harfbuzz).
PLEX_UNICODES = 20-7E,A0-17F,192,2C6,2C7,2D8-2DD,300-36F,3C0,2000-206F,20AC,20B9,20BD,2113,2116,2122,2126,212E,2190-2193,2202,2206,220F,2211,2212,2215,2219,221A,221E,222B,2248,2260,2264,2265,25CA,FB01,FB02
web-cut:
	for f in IBMPlexSans IBMPlexSans-Italic; do \
		hb-subset app/fonts/$$f.ttf --unicodes="$(PLEX_UNICODES)" --instance=wdth=100 --no-hinting -o tools/webbuild/cut/$$f.ttf || exit 1; done
	hb-subset app/fonts/JetBrainsMono.ttf --unicodes='*' --no-hinting --layout-features-=calt -o tools/webbuild/cut/JetBrainsMono.ttf
	cd app/fonts && shasum -a 256 IBMPlexSans.ttf IBMPlexSans-Italic.ttf JetBrainsMono.ttf > ../../tools/webbuild/cut/source.sha256

# After a Flutter upgrade (make web stops): the engine's fallback fonts
# anew in tools/webbuild/fonts.lock. Check the diff before committing it.
web-fonts: mermaid
	rm -rf app/build/web
	$(FLUTTER_WEB)
	go run ./tools/webbuild -lock-fonts app/build/web

# The app icon (Icon Composer, PNGs for macOS before 26, Linux's hicolor
# icons) and the mark.
icons:
	go run ./tools/icongen

# After an adapter's version changed in internal/<agent>/adapter/package.json:
# its lockfile again, and the sizes for its AdapterDownload and AdapterDisk.
adapters:
	tools/adapters.sh

# Records the Claude parity scenarios (SCENARIOS=all, or names with commas)
# into internal/features/chats/testdata/claude-parity (its README): Nushi's
# Go agent (nushid claude-acp) on CLAUDE_TEE_REAL, the claude to record,
# which runs on a fake Messages API with a throwaway home and config, no
# login. Then,
# when CLAUDE_SCHEMAS names claude's schemas (taken by hand, not in the
# repo; local.mk can set it), the drift from them, a report only.
SCENARIOS ?= all
CLAUDE_SCHEMAS ?=
claude-record:
	@test -n "$(CLAUDE_TEE_REAL)" || { echo "set CLAUDE_TEE_REAL to the claude to record"; exit 2; }
	go build -o bin/claude-tee github.com/afrase/claude-acp-go/claudeagent/claudetest/cmd/claude-tee
	go build -o bin/mcp-echo github.com/afrase/claude-acp-go/claudeagent/claudetest/cmd/mcp-echo
	go build -o bin/nushid ./cmd/nushid
	go run ./tools/claude-record -tee bin/claude-tee -mcp-echo bin/mcp-echo -claude "$(CLAUDE_TEE_REAL)" -only "$(SCENARIOS)" -- bin/nushid claude-acp
	@if [ -f "$(CLAUDE_SCHEMAS)" ]; then bin/claude-tee -schema-diff "$(CLAUDE_SCHEMAS)" internal/features/chats/testdata/claude-parity/*/cli*.jsonl; else echo "no schema drift report: set CLAUDE_SCHEMAS to claude's schemas"; fi

# The API's code from proto/, committed; CI checks it is what this makes.
# Go's plugins are go.mod's tools; Dart's are pinned in gen-tools, and
# connectrpc's output is formatted (it writes its own layout).
gen: gen-tools
	$(BUF) lint
	$(BUF) generate
	dart format app/lib/gen

# Dart's protoc plugins at the versions gen is checked with, activated in
# pub's global packages unless they are already.
PROTOC_DART := 25.1.0
CONNECT_DART := 2.0.0
gen-tools:
	@dart pub global list | grep -qx 'protoc_plugin $(PROTOC_DART)' || dart pub global activate protoc_plugin $(PROTOC_DART)
	@dart pub global list | grep -qx 'connectrpc $(CONNECT_DART)' || dart pub global activate connectrpc $(CONNECT_DART)

$(GOLANGCI): tools/lint/go.mod tools/lint/go.sum
	GOWORK=off go build -modfile=tools/lint/go.mod -o $@ github.com/golangci/golangci-lint/v2/cmd/golangci-lint

$(GOVULNCHECK): tools/lint/go.mod tools/lint/go.sum
	GOWORK=off go build -modfile=tools/lint/go.mod -o $@ golang.org/x/vuln/cmd/govulncheck

# Linters and format checks (.golangci.yml says which are on and why), and
# known vulnerabilities in the code the daemon, the relay and the tools call
# (govulncheck asks vuln.go.dev, so this needs the network). CI runs the
# parts as jobs of their own (.github/workflows/ci.yml); make check runs
# everything they do, and tools/ci-changes.sh's self-test (what CI's jobs
# skip for a change, ADR 0129).
lint: lint-go lint-dart lint-linux lint-windows
	tools/ci-changes.sh --self-test

# Go's: on macOS (the keychain's cgo needs its SDK).
lint-go: $(GOLANGCI) $(GOVULNCHECK)
	$(GOLANGCI) run ./...
	$(GOVULNCHECK) ./...
	GOWORK=off $(GOVULNCHECK) -C tools/lint github.com/golangci/golangci-lint/v2/cmd/golangci-lint golang.org/x/vuln/cmd/govulncheck

# The daemon and the tools built, vetted and linted for Linux without
# cgo, so macOS-only code (cgo, sysctl, the Mac's commands) outside a
# _darwin.go file fails here (ADR 0097), and the _linux.go files, which
# lint-go never sees, are linted, for both architectures (syscall's types
# differ: a conversion one needs, the other's unconvert reports): anywhere.
# On Linux, make test-go runs the daemon's tests (ADR 0101).
lint-linux: $(GOLANGCI)
	GOOS=linux CGO_ENABLED=0 go build ./...
	GOOS=linux CGO_ENABLED=0 go vet ./...
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 $(GOLANGCI) run ./...
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 $(GOLANGCI) run ./...

# Every package built, vetted and linted for Windows without cgo (ADR
# 0124): what it lacks answers errors.ErrUnsupported, code macOS and Linux
# share is in a _unix.go file, and a test of Unix's behaviour in a
# _unix_test.go one, so the _windows.go files and their tests are checked
# anywhere. unused is off: what only Unix's files call (the terminal's
# reading, which Windows's stand-in never starts) is unused there, and
# lint-go and lint-linux run it. amd64 only: Windows's types don't differ
# by architecture as Linux's do.
lint-windows: $(GOLANGCI)
	GOOS=windows CGO_ENABLED=0 go build ./...
	GOOS=windows CGO_ENABLED=0 go vet ./...
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 $(GOLANGCI) run --disable unused ./...

# The commit the protos are checked against for wire breaks (ADR 0004):
# where this branch grew from main; CI passes its change's base.
BREAKING_BASE ?= $(shell git merge-base HEAD origin/main 2>/dev/null)

# The protos' and Dart's, and the native code of the app and its Dart
# packages only in a platform's *_macos.dart, *_linux.dart or
# *_windows.dart files (tools/native-edge, ADR 0097, 0104, 0125), and the
# app's views built from the shared controls and tokens
# (tools/design-check, docs/design.md), and each app test file in one
# shard of the set its host needs (tools/test-shards -check): anywhere.
# buf breaking reads BREAKING_BASE's protos through git archive, which
# works in a worktree (where .git is a file buf can't clone from).
lint-dart:
	go run ./tools/native-edge $(addsuffix /lib,$(DART_DIRS))
	go run ./tools/design-check app/lib
	go run ./tools/test-shards -check
	$(BUF) lint
	@if [ -z "$(BREAKING_BASE)" ]; then echo "buf breaking: no base (BREAKING_BASE), skipped"; \
	else git cat-file -e "$(BREAKING_BASE)^{commit}" && echo "buf breaking against $(BREAKING_BASE)" && \
	git archive --format=tar "$(BREAKING_BASE)" buf.yaml proto | $(BUF) breaking --against '-#format=tar'; fi
	$(BUF) format --diff --exit-code
	@for d in $(DART_DIRS); do echo "flutter analyze $$d"; (cd $$d && flutter analyze --fatal-infos) || exit 1; done
	@for d in $(DART_DIRS); do (cd $$d && find lib test bin -name '*.dart' ! -path 'lib/gen/*' 2>/dev/null | xargs dart format --output=none --set-exit-if-changed) || exit 1; done


# With the race detector: about twice the time, still under the app's
# tests in CI, and a goroutine nothing waits for shows up here first.
# GOTESTFLAGS adds flags (CI's -shuffle=on, which finds tests that pass
# only in their file's order; go test prints the seed to run it again).
# Git in the tests reads no config or ignore file of the user's: a global
# excludes file (XDG_CONFIG_HOME's git/ignore) changed what git check-ignore
# said in the tests' own repositories. A test that hangs (the tests wait
# with plain receives, no deadlines of their own) ends at 3 minutes, not
# go test's 10, with every goroutine's stack showing where it stuck.
test-go:
	GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 XDG_CONFIG_HOME=$(CURDIR)/internal/testcheck/noconfig go test -race -timeout 3m $(GOTESTFLAGS) ./...

# The packages run anywhere with Go (remote_transport's interop builds a
# Go peer), and in Chrome where there's one.
test-packages:
	cd packages/uds_transport && dart test
	cd packages/noise && dart test $(if $(CHROME),&& dart test -p chrome)
	cd packages/remote_transport && dart test $(if $(CHROME),&& dart test -p chrome test/gzip_web_test.dart)
	cd packages/markdown && flutter test
	cd packages/svg_path && flutter test

# The app's widget tests and goldens, the files tools/test-shards gives
# (ADR 0129): SET=macos the files that need a Mac (goldens), SET=linux the
# rest, all of them by default; SHARD=i/n the ith of n shards split by
# app/test/timings.tsv, as CI's jobs run them. Each shard's files go
# slowest first, so none is left running at the end. NUSHI_TEST_SET
# tells the tests their set: a golden in the Linux set's fails
# (flutter_test_config.dart). FLUTTER_TEST_FLAGS adds flags (CI's
# --concurrency, and its --test-randomize-ordering-seed=random, which
# runs each file's tests in a random order and finds those that pass
# only in the file's; flutter test prints the seed, and the same flag
# with it runs that order again). A tool that fails stops it: flutter
# test given no file would run them all.
APP_SET = $(or $(SET),all)
APP_SHARD = $(or $(SHARD),1/1)
test-app:
	@files=$$(go run ./tools/test-shards -set '$(APP_SET)' -shard '$(APP_SHARD)') || exit 2; \
	echo "flutter test $(FLUTTER_TEST_FLAGS): $$(echo "$$files" | wc -l | tr -d ' ') files, set $(APP_SET), shard $(APP_SHARD)"; \
	cd app && NUSHI_TEST_SET='$(APP_SET)' flutter test $(FLUTTER_TEST_FLAGS) $$files

# app/test/timings.tsv anew from the test times of CI's app shards in
# RUN, a run of every job (gh run list --workflow CI), downloaded by gh
# into bin/test-times-<run>: when the suite's times have changed
# (test-shards -check says when many files are missing from the table).
# CI's times, not this machine's: a Mac here runs the golden files about
# three times faster than CI's macOS runner, the rest only about twice.
test-timings:
	@test -n "$(RUN)" || { echo "RUN=<a CI run's id>: gh run list --workflow CI"; exit 2; }
	gh run download $(RUN) -p 'test-times-*' -D bin/test-times-$(RUN)
	go run ./tools/test-shards -timings bin/test-times-$(RUN)/*/test-times.json

# The Mac window's placement maths (app/macos/Runner/Placement.swift, ADR
# 0093), what ⌘V attaches (Clipboard.swift, on a pasteboard of its own)
# and what AppKit takes for its title bar and where the window's buttons
# sit (TitleBar.swift, a window never shown), and what Flutter's engine was
# told of the mouse (EngineMouse.swift), with their tests, built by swiftc
# and run with no window on screen: an XCTest target is hosted by the app,
# so xcodebuild test would launch Nushi (macOS only).
test-window:
	@mkdir -p bin
	xcrun swiftc -o bin/placement-test app/macos/Runner/Placement.swift app/macos/PlacementTests/main.swift
	bin/placement-test
	xcrun swiftc -o bin/clipboard-test app/macos/Runner/Clipboard.swift app/macos/ClipboardTests/main.swift
	bin/clipboard-test
	xcrun swiftc -o bin/titlebar-test app/macos/Runner/TitleBar.swift app/macos/TitleBarTests/main.swift
	bin/titlebar-test
	xcrun swiftc -o bin/enginemouse-test app/macos/Runner/EngineMouse.swift app/macos/EngineMouseTests/main.swift
	bin/enginemouse-test

# The web app in Chrome with the real nushid and nushi-relay (macOS, or
# Linux with a Chrome, as CI runs it). Without a Chrome it says so and
# passes, but on CI, which must run it.
test-web:
ifeq ($(CHROME),)
	@if [ -n "$$CI" ]; then echo "test-web: no Chrome on CI"; exit 1; fi; echo "test-web: no Chrome (CHROME_EXECUTABLE, or google-chrome on PATH), skipped"
else
	cd app && flutter test --platform chrome test/web
endif

# The README's screenshots (docs/images): the real app on a fake daemon with
# made-up data, drawn by app/test/screenshots/readme_shots.dart. Not part of
# make check (the file's name doesn't end in _test.dart).
screenshots:
	cd app && flutter test --update-goldens test/screenshots/readme_shots.dart

# The component gallery (docs/design.md): every shared control in every
# state, a sheet per group, dark and light, as PNGs in app/build/gallery
# (app/test/screenshots/gallery.dart). Not part of make check;
# gallery_test.dart keeps a few sheets as goldens.
GALLERY ?= $(CURDIR)/app/build/gallery
gallery:
	cd app && NUSHI_RENDERS='$(GALLERY)' flutter test test/screenshots/gallery.dart
	@echo "gallery in $(GALLERY)"

# The one check before a push (tools/check): make lint and every test
# target (the app's suite once), then flutter build macos (on Linux,
# flutter build linux; build only). The app's suite and the web's tests
# run beside the lints and the other tests; a failure stops nothing. A line
# per step, then what failed with the path of its full log, so its output
# needs no pipe. FLUTTER_TEST_FLAGS works as for test-app (--concurrency 3
# unless it says).
check:
	@go build -o bin/check ./tools/check
	@bin/check

# What changed in the goldens against BASE (a ref, HEAD by default), new and
# removed ones included: each file's size, changed box and pixel count, with
# identical boxes grouped. TO=<ref> compares that ref instead of the working
# tree. ROWS=0-44 fails on a change outside those pixel rows; a golden that
# changed size always fails.
BASE ?= HEAD
golden-diff:
	@go run ./tools/golden-diff -base '$(BASE)' -to '$(TO)' -rows '$(ROWS)'

# The windows the app's tests draw, as PNGs to look at, never committed:
# with NUSHI_RENDERS set, harness.dart's render writes each into RENDERS
# (app/build/renders by default). TEST=test/<file>_test.dart for one file's,
# every file's otherwise.
RENDERS ?= $(CURDIR)/app/build/renders
renders:
	cd app && NUSHI_RENDERS='$(RENDERS)' flutter test $(TEST)
	@echo "renders in $(RENDERS)"

# Hand-written lines, without tests or generated code (the size limits).
lines:
	@echo "go daemon: $$(find cmd/nushid internal -name '*.go' ! -name '*_test.go' ! -path 'internal/gen/*' ! -path 'internal/ante/antetest/*' ! -path 'internal/pi/pitest/*' ! -path 'internal/acptest/*' ! -path 'internal/testcheck/*' | xargs cat | wc -l)"
	@echo "go relay and noise: $$(find cmd/nushi-relay relay noiseconn -name '*.go' ! -name '*_test.go' 2>/dev/null | xargs cat | wc -l)"
	@echo "dart app: $$(find app/lib -name '*.dart' ! -path 'app/lib/gen/*' | xargs cat | wc -l)"
	@echo "dart packages: $$(find packages -path '*/lib/*.dart' | xargs cat | wc -l)"
