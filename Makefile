# Dart's protoc plugins: dart pub global activate protoc_plugin; dart pub global activate connectrpc
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

.PHONY: run daemon stop app package install gen test lint check lines relay icons adapters

# Starts the daemon in the background (unless one is running), then the app.
run: daemon app

daemon:
	go build -o bin/nushid ./cmd/nushid
	mkdir -p "$(DATA)"
	bin/nushid >>"$(DATA)/nushid.log" 2>&1 &

# Stops the daemon listening in $(DATA), not any other.
stop:
	lsof -a -c nushid -t "$(DATA)/nushid.sock" | xargs kill 2>/dev/null || true

app:
	cd app && flutter run -d macos

# A release app with nushid inside, in a background-only helper app
# (ADR 0036), signed with $(SIGN). The app starts it when no daemon is running,
# and launchd at login through start-daemon when Start at login is on.
package:
	cd app && flutter build macos --release
	rm -rf "$(RELEASE)/Contents/MacOS/nushid" "$(RELEASE)/Contents/Helpers"
	mkdir -p "$(HELPER)/Contents/MacOS" "$(HELPER)/Contents/Resources"
	go build -o "$(HELPER)/Contents/MacOS/nushid" ./cmd/nushid
	cp app/macos/Daemon/Info.plist "$(HELPER)/Contents/"
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

# The app icon (Icon Composer, and PNGs for macOS before 26) and the mark.
icons:
	go run ./tools/icongen

# After an adapter's version changed in internal/<agent>/adapter/package.json:
# its lockfile again, and the sizes for its AdapterDownload and AdapterDisk.
adapters:
	tools/adapters.sh

gen:
	$(BUF) lint
	$(BUF) generate

$(GOLANGCI): tools/lint/go.mod tools/lint/go.sum
	GOWORK=off go build -modfile=tools/lint/go.mod -o $@ github.com/golangci/golangci-lint/v2/cmd/golangci-lint

$(GOVULNCHECK): tools/lint/go.mod tools/lint/go.sum
	GOWORK=off go build -modfile=tools/lint/go.mod -o $@ golang.org/x/vuln/cmd/govulncheck

# Linters and format checks (.golangci.yml says which are on and why), and
# known vulnerabilities in the code the daemon, the relay and the tools call
# (govulncheck asks vuln.go.dev, so this needs the network).
lint: $(GOLANGCI) $(GOVULNCHECK)
	$(GOLANGCI) run ./...
	$(GOVULNCHECK) ./...
	GOWORK=off $(GOVULNCHECK) -C tools/lint github.com/golangci/golangci-lint/v2/cmd/golangci-lint golang.org/x/vuln/cmd/govulncheck
	$(BUF) lint
	$(BUF) format --diff --exit-code
	@for d in $(DART_DIRS); do echo "flutter analyze $$d"; (cd $$d && flutter analyze --fatal-infos) || exit 1; done
	@for d in $(DART_DIRS); do (cd $$d && find lib test bin -name '*.dart' ! -path 'lib/gen/*' 2>/dev/null | xargs dart format --output=none --set-exit-if-changed) || exit 1; done

check: lint test

test:
	go test ./...
	cd packages/uds_transport && dart test
	cd packages/noise && dart test
	cd packages/remote_transport && dart test
	cd packages/markdown && flutter test
	cd packages/svg_path && flutter test
	cd app && flutter test

# Hand-written lines, without tests or generated code (the size limits).
lines:
	@echo "go daemon: $$(find cmd/nushid internal -name '*.go' ! -name '*_test.go' ! -path 'internal/gen/*' ! -path 'internal/ante/antetest/*' ! -path 'internal/pig/pigtest/*' ! -path 'internal/acptest/*' | xargs cat | wc -l)"
	@echo "go relay and noise: $$(find cmd/nushi-relay relay noiseconn -name '*.go' ! -name '*_test.go' 2>/dev/null | xargs cat | wc -l)"
	@echo "dart app: $$(find app/lib -name '*.dart' ! -path 'app/lib/gen/*' | xargs cat | wc -l)"
	@echo "dart packages: $$(find packages -path '*/lib/*.dart' | xargs cat | wc -l)"
