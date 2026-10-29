# Dart's protoc plugins (make gen-tools), from pub's global bin.
export PATH := $(HOME)/.pub-cache/bin:$(PATH)
BUF := go run github.com/bufbuild/buf/cmd/buf@v1.75.0
# golangci-lint and govulncheck, pinned in their own module so the daemon's
# go.mod doesn't take their dependencies; built into bin/ (go tool -modfile
# can't run beside a go.work).
GOLANGCI := bin/golangci-lint
GOVULNCHECK := bin/govulncheck
DART_DIRS := app packages/uds_transport packages/noise packages/remote_transport packages/markdown packages/svg_path
# NUSHI_DATA=<folder> runs a second daemon and app beside the usual ones.
DATA := $(or $(NUSHI_DATA),$(HOME)/Library/Application Support/Nushi)
RELEASE := app/build/macos/Build/Products/Release/Nushi.app
HELPER := $(RELEASE)/Contents/Helpers/Nushi Daemon.app
# local.mk (not committed) can set COPY_TO=<folder>: make install also copies the app there.
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

.PHONY: run daemon stop app package install gen gen-tools test test-go test-packages test-app test-web lint lint-go lint-dart check lines relay icons adapters web web-fonts web-plex mermaid

# Starts the daemon in the background (unless one is running), then the app.
run: daemon app

daemon:
	go build -o bin/nushid ./cmd/nushid
	mkdir -p "$(DATA)"
	bin/nushid >>"$(DATA)/nushid.log" 2>&1 &

# Stops the daemon listening in $(DATA), not any other.
stop:
	lsof -a -c nushid -t "$(DATA)/nushid.sock" | xargs kill 2>/dev/null || true

app: mermaid
	cd app && flutter run -d macos

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

install: package
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(HOME)/Applications/Nushi.app" "$(HOME)/Applications/Nushi Next.app"
	ditto "$(RELEASE)" "$(HOME)/Applications/Nushi.app"
	if [ -n "$(COPY_TO)" ]; then rm -rf "$(COPY_TO)/Nushi.app" "$(COPY_TO)/Nushi Next.app" && ditto "$(RELEASE)" "$(COPY_TO)/Nushi.app"; fi

# The relay (ADR 0033), one static binary: bin/nushi-relay -h lists its flags.
relay:
	CGO_ENABLED=0 go build -o bin/nushi-relay ./cmd/nushi-relay

# The phone's web app (ADR 0052), served by the relay's -web: app/build/web.
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
# changes (make web stops). Needs HarfBuzz's hb-subset (brew install harfbuzz).
PLEX_UNICODES = 20-7E,A0-17F,192,2C6,2C7,2D8-2DD,300-36F,3C0,2000-206F,20AC,20B9,20BD,2113,2116,2122,2126,212E,2190-2193,2202,2206,220F,2211,2212,2215,2219,221A,221E,222B,2248,2260,2264,2265,25CA,FB01,FB02
web-plex:
	for f in IBMPlexSans IBMPlexSans-Italic; do \
		hb-subset app/fonts/$$f.ttf --unicodes="$(PLEX_UNICODES)" --instance=wdth=100 --no-hinting -o tools/webbuild/plex/$$f.ttf || exit 1; done
	cd app/fonts && shasum -a 256 IBMPlexSans.ttf IBMPlexSans-Italic.ttf > ../../tools/webbuild/plex/source.sha256

# After a Flutter upgrade (make web stops): the engine's fallback fonts
# anew in tools/webbuild/fonts.lock. Check the diff before committing it.
web-fonts: mermaid
	rm -rf app/build/web
	$(FLUTTER_WEB)
	go run ./tools/webbuild -lock-fonts app/build/web

# The app icon (Icon Composer, and PNGs for macOS before 26) and the mark.
icons:
	go run ./tools/icongen

# After an adapter's version changed in internal/<agent>/adapter/package.json:
# its lockfile again, and the sizes for its AdapterDownload and AdapterDisk.
adapters:
	tools/adapters.sh

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
# everything they do.
lint: lint-go lint-dart

# Go's: on macOS (the keychain's cgo needs its SDK).
lint-go: $(GOLANGCI) $(GOVULNCHECK)
	$(GOLANGCI) run ./...
	$(GOVULNCHECK) ./...
	GOWORK=off $(GOVULNCHECK) -C tools/lint github.com/golangci/golangci-lint/v2/cmd/golangci-lint golang.org/x/vuln/cmd/govulncheck

# The protos' and Dart's: anywhere.
lint-dart:
	$(BUF) lint
	$(BUF) format --diff --exit-code
	@for d in $(DART_DIRS); do echo "flutter analyze $$d"; (cd $$d && flutter analyze --fatal-infos) || exit 1; done
	@for d in $(DART_DIRS); do (cd $$d && find lib test bin -name '*.dart' ! -path 'lib/gen/*' 2>/dev/null | xargs dart format --output=none --set-exit-if-changed) || exit 1; done

check: lint test

test: test-go test-packages test-app test-web

# With the race detector: about twice the time, still under the app's
# tests in CI, and a goroutine nothing waits for shows up here first.
# GOTESTFLAGS adds flags (CI's -shuffle=on, which finds tests that pass
# only in their file's order; go test prints the seed to run it again).
test-go:
	go test -race $(GOTESTFLAGS) ./...

# The packages run anywhere with Go (remote_transport's interop builds a
# Go peer) and Chrome.
test-packages:
	cd packages/uds_transport && dart test
	cd packages/noise && dart test && dart test -p chrome
	cd packages/remote_transport && dart test && dart test -p chrome test/gzip_web_test.dart
	cd packages/markdown && flutter test
	cd packages/svg_path && flutter test

# The app's widget tests and goldens (macOS: the goldens are drawn with its
# text rendering, and the end-to-end tests run nushid). SHARD=i/n runs
# every nth test file from the ith, as CI's shards do (each file compiles
# once, in one shard); FLUTTER_TEST_FLAGS adds flags (CI's --concurrency).
APP_TESTS = $(if $(SHARD),$(shell cd app && find test -name '*_test.dart' ! -path 'test/web/*' | LC_ALL=C sort | awk -v s='$(SHARD)' 'BEGIN { split(s, a, "/") } (NR - 1) % a[2] == a[1] - 1'))
test-app:
	cd app && flutter test $(FLUTTER_TEST_FLAGS) $(APP_TESTS)

# The web app in Chrome with the real nushid and nushi-relay (macOS).
test-web:
	cd app && flutter test --platform chrome test/web

# Hand-written lines, without tests or generated code (the size limits).
lines:
	@echo "go daemon: $$(find cmd/nushid internal -name '*.go' ! -name '*_test.go' ! -path 'internal/gen/*' ! -path 'internal/ante/antetest/*' ! -path 'internal/pig/pigtest/*' ! -path 'internal/acptest/*' | xargs cat | wc -l)"
	@echo "go relay and noise: $$(find cmd/nushi-relay relay noiseconn -name '*.go' ! -name '*_test.go' 2>/dev/null | xargs cat | wc -l)"
	@echo "dart app: $$(find app/lib -name '*.dart' ! -path 'app/lib/gen/*' | xargs cat | wc -l)"
	@echo "dart packages: $$(find packages -path '*/lib/*.dart' | xargs cat | wc -l)"
