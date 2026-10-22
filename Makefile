# Dart's protoc plugins: dart pub global activate protoc_plugin; dart pub global activate connectrpc
export PATH := $(HOME)/.pub-cache/bin:$(PATH)
BUF := go run github.com/bufbuild/buf/cmd/buf@v1.75.0
DATA := $(HOME)/Library/Application Support/Nushi Next
RELEASE := app/build/macos/Build/Products/Release/Nushi Next.app

.PHONY: run daemon stop app package install gen test lines

# Starts the daemon in the background (unless one is running), then the app.
run: daemon app

daemon:
	go build -o bin/nushid ./cmd/nushid
	mkdir -p "$(DATA)"
	bin/nushid >>"$(DATA)/nushid.log" 2>&1 &

stop:
	pkill -x nushid || true

app:
	cd app && flutter run -d macos

# A release app with nushid inside, ad-hoc signed. The app starts its
# nushid when no daemon is running.
package:
	cd app && flutter build macos --release
	go build -o "$(RELEASE)/Contents/MacOS/nushid" ./cmd/nushid
	codesign --force --deep --sign - "$(RELEASE)"

install: package
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(HOME)/Applications/Nushi Next.app"
	ditto "$(RELEASE)" "$(HOME)/Applications/Nushi Next.app"

gen:
	$(BUF) lint
	$(BUF) generate

test:
	go test ./...
	cd packages/uds_transport && dart test
	cd packages/markdown && flutter test
	cd app && flutter test

# Hand-written lines, without tests or generated code (the size limits).
lines:
	@echo "go daemon: $$(find cmd internal -name '*.go' ! -name '*_test.go' ! -path 'internal/gen/*' | xargs cat | wc -l)"
	@echo "go acp: $$(find acp -name '*.go' ! -name '*_test.go' ! -name '*_gen.go' ! -path 'acp/acptest/*' | xargs cat | wc -l)"
	@echo "dart app: $$(find app/lib -name '*.dart' ! -path 'app/lib/gen/*' | xargs cat | wc -l)"
	@echo "dart packages: $$(find packages -path '*/lib/*.dart' | xargs cat | wc -l)"
