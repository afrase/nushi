# Dart's protoc plugins: dart pub global activate protoc_plugin; dart pub global activate connectrpc
export PATH := $(HOME)/.pub-cache/bin:$(PATH)
BUF := go run github.com/bufbuild/buf/cmd/buf@v1.75.0
DATA := $(HOME)/Library/Application Support/Nushi Next

.PHONY: run daemon stop app gen test lines

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

gen:
	$(BUF) lint
	$(BUF) generate

test:
	go test ./...
	cd packages/uds_transport && dart test

# Hand-written lines, without tests or generated code (the size limits).
lines:
	@echo "go: $$(find cmd internal acp -name '*.go' ! -name '*_test.go' ! -path 'internal/gen/*' 2>/dev/null | xargs cat | wc -l)"
	@echo "dart app: $$(find app/lib -name '*.dart' ! -path 'app/lib/gen/*' | xargs cat | wc -l)"
	@echo "dart packages: $$(find packages -path '*/lib/*.dart' | xargs cat | wc -l)"
