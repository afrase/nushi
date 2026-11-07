package sysproxy

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os/exec"
	"strconv"
	"time"

	"github.com/afrase/nushi/internal/procgroup"
)

// systemLookup reads the network settings `scutil --proxy` prints.
func systemLookup(u *url.URL, secure bool) ([]*url.URL, time.Duration) {
	ctx, cancel := context.WithTimeout(context.Background(), Timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "/usr/sbin/scutil", "--proxy")
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if err != nil {
		return []*url.URL{nil}, 30 * time.Second
	}
	proxies, ok := fromSettings(parse(out), u, secure)
	if !ok {
		return proxies, 30 * time.Second
	}
	return proxies, 5 * time.Minute
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
