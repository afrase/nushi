module github.com/afrase/nushi

go 1.27.1

require (
	connectrpc.com/connect v1.21.1
	github.com/creack/pty v1.1.24
	golang.org/x/sys v0.49.0
	google.golang.org/protobuf v1.36.12
)

tool (
	connectrpc.com/connect/cmd/protoc-gen-connect-go
	google.golang.org/protobuf/cmd/protoc-gen-go
)
