module github.com/afrase/nushi

go 1.27.3

require (
	connectrpc.com/connect v1.21.1
	github.com/BurntSushi/toml v1.6.0
	github.com/afrase/acp-go v0.2.0
	github.com/andybalholm/brotli v1.2.0
	github.com/cli/go-gh/v2 v2.17.0
	github.com/creack/pty v1.1.24
	github.com/flynn/noise v1.1.0
	github.com/gorilla/websocket v1.5.3
	github.com/yuin/goldmark v1.8.6
	golang.org/x/crypto v0.58.0
	golang.org/x/net v0.60.0
	golang.org/x/sys v0.49.0
	google.golang.org/protobuf v1.36.12
	gopkg.in/yaml.v3 v3.0.1
)

require (
	github.com/cli/safeexec v1.0.1 // indirect
	golang.org/x/text v0.43.0 // indirect
)

tool (
	connectrpc.com/connect/cmd/protoc-gen-connect-go
	google.golang.org/protobuf/cmd/protoc-gen-go
)
