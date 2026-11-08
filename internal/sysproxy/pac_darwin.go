package sysproxy

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strconv"

	"github.com/afrase/nushi/internal/procgroup"
)

// pac fetches the PAC file at pacURL (directly) and asks macOS what it says
// for u, which is only a scheme, host and port.
func pac(pacURL string, u *url.URL) ([]*url.URL, error) {
	ctx, cancel := context.WithTimeout(context.Background(), Timeout)
	defer cancel()
	script, err := fetch(ctx, pacURL)
	if err != nil {
		return nil, err
	}
	// CFNetwork knows http and https; a WebSocket URL is asked as either.
	asked := url.URL{Scheme: map[string]string{"wss": "https", "ws": "http", "https": "https", "http": "http"}[u.Scheme], Host: u.Host, Path: "/"}
	return evaluate(ctx, script, asked)
}

// pacTransport fetches PAC files, directly; a connection isn't kept for
// the next fetch, minutes away.
var pacTransport = &http.Transport{Proxy: nil, DisableKeepAlives: true}

// fetch reads a PAC file: http(s), directly, or file://; 1 MB at most.
func fetch(ctx context.Context, raw string) ([]byte, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, err
	}
	var r io.ReadCloser
	if u.Scheme == "file" {
		if r, err = os.Open(u.Path); err != nil {
			return nil, err
		}
	} else {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, raw, http.NoBody)
		if err != nil {
			return nil, err
		}
		resp, err := pacTransport.RoundTrip(req)
		if err != nil {
			return nil, err
		}
		if resp.StatusCode != http.StatusOK {
			_ = resp.Body.Close()
			return nil, fmt.Errorf("the PAC file: %s", resp.Status)
		}
		r = resp.Body
	}
	defer r.Close() //nolint:errcheck // read-only
	b, err := io.ReadAll(io.LimitReader(r, 1<<20+1))
	if err == nil && len(b) > 1<<20 {
		err = errors.New("the PAC file is over 1 MB")
	}
	return b, err
}

// pacScript evaluates a PAC file (on stdin) for a URL (its argument) with
// CFNetwork, and prints the proxies it names as JSON.
const pacScript = `ObjC.import('Foundation'); ObjC.import('CoreServices');
function run(argv) {
  const data = $.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
  const script = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding);
  const res = $.CFNetworkCopyProxiesForAutoConfigurationScript(script, $.NSURL.URLWithString(argv[0]), Ref());
  const list = ObjC.castRefToObject(res), out = [];
  for (let i = 0; i < list.count; i++) out.push(ObjC.deepUnwrap(list.objectAtIndex(i)));
  return JSON.stringify(out);
}`

// evaluate asks macOS what the PAC file script says for asked: CFNetwork,
// through osascript.
func evaluate(ctx context.Context, script []byte, asked url.URL) ([]*url.URL, error) {
	cmd := exec.CommandContext(ctx, "/usr/bin/osascript", "-l", "JavaScript", "-e", pacScript, asked.String()) //nolint:gosec // osascript with our own script
	cmd.Stdin = bytes.NewReader(script)
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("evaluating the PAC file: %w", err)
	}
	var entries []map[string]any
	if err := json.Unmarshal(out, &entries); err != nil {
		return nil, err
	}
	var proxies []*url.URL
	for _, e := range entries {
		host, _ := e["kCFProxyHostNameKey"].(string)
		port, _ := e["kCFProxyPortNumberKey"].(float64)
		addr := net.JoinHostPort(host, strconv.Itoa(int(port)))
		switch e["kCFProxyTypeKey"] {
		case "kCFProxyTypeNone":
			proxies = append(proxies, nil)
		case "kCFProxyTypeHTTP", "kCFProxyTypeHTTPS":
			proxies = append(proxies, &url.URL{Scheme: "http", Host: addr})
		case "kCFProxyTypeSOCKS":
			proxies = append(proxies, &url.URL{Scheme: "socks5", Host: addr})
		}
	}
	if len(proxies) == 0 {
		return nil, errors.New("the PAC file named no proxy Nushi can use")
	}
	return proxies, nil
}
