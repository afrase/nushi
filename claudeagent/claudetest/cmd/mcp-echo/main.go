// Command mcp-echo is a stdio MCP server small enough to read, for
// recording claude calling an MCP tool with nothing on the network: one
// tool, echo, which answers with the text it is given.
//
//	mcp-echo
//
// It speaks MCP's JSON-RPC a line at a time on stdin and stdout, and ends
// at stdin's end.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
)

func main() {
	if err := serve(os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "mcp-echo:", err)
		os.Exit(1)
	}
}

// protocolVersion is the MCP version answered when the client asks for
// none.
const protocolVersion = "2025-06-18"

// message is a JSON-RPC message: a request (method and id), a
// notification (method, no id) or an answer.
type message struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  any             `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// echoTool is the one tool's description, as tools/list gives it.
var echoTool = map[string]any{
	"name":        "echo",
	"description": "Answers with the text it is given.",
	"inputSchema": map[string]any{
		"type":       "object",
		"properties": map[string]any{"text": map[string]any{"type": "string", "description": "The text to answer with."}},
		"required":   []string{"text"},
	},
}

// serve answers the requests on r on w until r ends. Lines that aren't
// JSON-RPC are passed over; notifications get no answer.
func serve(r io.Reader, w io.Writer) error {
	sc := bufio.NewScanner(r)
	sc.Buffer(nil, 16<<20)
	enc := json.NewEncoder(w)
	for sc.Scan() {
		var m message
		if json.Unmarshal(sc.Bytes(), &m) != nil || m.Method == "" || len(m.ID) == 0 {
			continue
		}
		result, err := answer(m.Method, m.Params)
		out := message{JSONRPC: "2.0", ID: m.ID, Result: result, Error: err}
		if err != nil {
			out.Result = nil
		}
		if err := enc.Encode(out); err != nil {
			return err
		}
	}
	return sc.Err()
}

// answer is the result of a request, or its error.
func answer(method string, params json.RawMessage) (any, *rpcError) {
	switch method {
	case "initialize":
		var p struct {
			ProtocolVersion string `json:"protocolVersion"`
		}
		_ = json.Unmarshal(params, &p)
		if p.ProtocolVersion == "" {
			p.ProtocolVersion = protocolVersion
		}
		return map[string]any{
			"protocolVersion": p.ProtocolVersion, // whatever the client speaks: one tool needs nothing newer
			"capabilities":    map[string]any{"tools": map[string]any{}},
			"serverInfo":      map[string]any{"name": "mcp-echo", "version": "1.0.0"},
		}, nil
	case "ping":
		return map[string]any{}, nil
	case "tools/list":
		return map[string]any{"tools": []any{echoTool}}, nil
	case "tools/call":
		var p struct {
			Name      string `json:"name"`
			Arguments struct {
				Text string `json:"text"`
			} `json:"arguments"`
		}
		if err := json.Unmarshal(params, &p); err != nil || p.Name != "echo" {
			return nil, &rpcError{Code: -32602, Message: "no such tool"}
		}
		return map[string]any{"content": []any{map[string]any{"type": "text", "text": p.Arguments.Text}}}, nil
	default:
		return nil, &rpcError{Code: -32601, Message: "method not found: " + method}
	}
}
