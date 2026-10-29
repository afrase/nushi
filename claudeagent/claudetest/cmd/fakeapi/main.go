// Command fakeapi serves a fake Anthropic Messages API on loopback, for
// running the real claude with no login (package fakeapi says what it
// answers):
//
//	fakeapi -script <api.json, or a scenario's folder> [-addr 127.0.0.1:0]
//
// It prints ANTHROPIC_BASE_URL=<its URL> and serves until interrupted,
// then says which requests no turn matched and how many turns were left.
// Point claude at it with that variable and any dummy ANTHROPIC_API_KEY;
// it refuses a key that looks real.
package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/afrase/nushi/claudeagent/claudetest/fakeapi"
)

func main() {
	script := flag.String("script", "", "the script: a JSON file, or a scenario's folder with api.json")
	addr := flag.String("addr", "127.0.0.1:0", "where to listen, on loopback")
	flag.Parse()
	if *script == "" || flag.NArg() > 0 {
		flag.Usage()
		os.Exit(2)
	}
	s, err := fakeapi.Load(*script)
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	srv := fakeapi.New(s, log)
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	url, stop, err := srv.Start(ctx, *addr)
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, err)
		os.Exit(1) //nolint:gocritic // nothing to cancel yet
	}
	_, _ = fmt.Fprintln(os.Stdout, "ANTHROPIC_BASE_URL="+url)
	<-ctx.Done()
	_ = stop()
	for _, m := range srv.Misses() {
		log.Warn("no turn matched", "path", m.Path, "model", m.Model)
	}
	log.Info("done", "requests", len(srv.Served()), "turnsLeft", srv.Left())
}
