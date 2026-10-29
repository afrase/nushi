package fakeapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"slices"
	"strings"
	"sync"
	"time"
)

// Server is the fake API, an http.Handler. Its zero value isn't usable:
// make one with New.
type Server struct {
	script Script
	log    *slog.Logger

	mu     sync.Mutex
	next   int // the next turn
	ids    int // ids made so far
	served []Served
}

// Served is a request the fake API answered: its method, path and model,
// and how it answered ("turn N", "side N", "canned", "miss", "refused",
// "count_tokens", "models", "not found").
type Served struct {
	Method string
	Path   string
	Model  string
	Answer string
}

// New makes a fake API that answers with s. log (nil: none) gets a line a
// request, never its content.
func New(s *Script, log *slog.Logger) *Server {
	if log == nil {
		log = slog.New(slog.DiscardHandler)
	}
	return &Server{script: *s, log: log}
}

// Served are the requests answered so far, in order.
func (s *Server) Served() []Served {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.served)
}

// Misses are the requests for a reply no turn matched, other than
// claude's small requests of its own.
func (s *Server) Misses() []Served {
	var out []Served
	for _, r := range s.Served() {
		if r.Answer == "miss" {
			out = append(out, r)
		}
	}
	return out
}

// Left is how many turns no request took.
func (s *Server) Left() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.script.Turns) - s.next
}

// Start serves the fake API on addr, which must be on loopback
// ("127.0.0.1:0" picks a port), until stop; ctx is for starting only,
// and a done one starts nothing. url is its base URL, for
// ANTHROPIC_BASE_URL.
func (s *Server) Start(ctx context.Context, addr string) (url string, stop func() error, err error) {
	if err := ctx.Err(); err != nil { // Listen doesn't look at it once it has an address
		return "", nil, err
	}
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return "", nil, err
	}
	if ip := net.ParseIP(host); host != "localhost" && (ip == nil || !ip.IsLoopback()) {
		return "", nil, fmt.Errorf("fakeapi: %s isn't on loopback", addr)
	}
	l, err := (&net.ListenConfig{}).Listen(ctx, "tcp", addr)
	if err != nil {
		return "", nil, err
	}
	srv := &http.Server{Handler: s, ReadHeaderTimeout: 10 * time.Second}
	go func() { _ = srv.Serve(l) }()
	return "http://" + l.Addr().String(), func() error {
		ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Second)
		defer cancel()
		if err := srv.Shutdown(ctx); err != nil {
			return srv.Close() // a hanging turn's stream is still open
		}
		return nil
	}, nil
}

// ServeHTTP answers one request.
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if realKey(r) {
		// The key itself is never logged.
		s.note(r, "", "refused")
		apiError(w, &APIError{Status: http.StatusUnauthorized, Type: "authentication_error", Message: "fakeapi refuses a real Anthropic key: give it a dummy one"})
		return
	}
	path := strings.TrimSuffix(r.URL.Path, "/")
	switch {
	case r.Method == http.MethodPost && path == "/v1/messages":
		s.messages(w, r)
	case r.Method == http.MethodPost && path == "/v1/messages/count_tokens":
		body, _ := io.ReadAll(io.LimitReader(r.Body, 64<<20))
		var req request
		_ = json.Unmarshal(body, &req)
		s.note(r, req.Model, "count_tokens")
		writeJSON(w, map[string]any{"input_tokens": max(1, len(body)/4)})
	case r.Method == http.MethodGet && path == "/v1/models":
		s.note(r, "", "models")
		s.models(w)
	case r.Method == http.MethodGet && strings.HasPrefix(path, "/v1/models/"):
		id := strings.TrimPrefix(path, "/v1/models/")
		s.note(r, id, "models")
		writeJSON(w, model(id))
	default:
		s.note(r, "", "not found")
		apiError(w, &APIError{Status: http.StatusNotFound, Type: "not_found_error", Message: "fakeapi doesn't serve " + r.Method + " " + path})
	}
}

// realKey says whether r carries what looks like a real Anthropic key
// (an API key or an OAuth token: "sk-ant-…").
func realKey(r *http.Request) bool {
	for _, v := range []string{r.Header.Get("X-Api-Key"), strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")} {
		if strings.HasPrefix(strings.TrimSpace(v), "sk-ant-") {
			return true
		}
	}
	return false
}

// messages answers a request for a reply.
func (s *Server) messages(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 256<<20))
	var req request
	if err == nil {
		err = json.Unmarshal(body, &req)
	}
	if err != nil {
		s.note(r, "", "bad request")
		apiError(w, &APIError{Status: http.StatusBadRequest, Type: "invalid_request_error", Message: "fakeapi: the body isn't a request: " + err.Error()})
		return
	}
	turn, answer := s.pick(&req)
	s.note(r, req.Model, answer)
	if turn.Error != nil {
		apiError(w, turn.Error)
		return
	}
	vals, _ := turn.Match.captured(&req)
	rep := newReply(turn, req.Model, len(body), s.newID, vals)
	if !req.Stream {
		writeJSON(w, rep.message())
		return
	}
	if err := rep.stream(r.Context(), w); err != nil && !errors.Is(err, context.Canceled) {
		s.log.Warn("fakeapi: streaming a reply", "err", err)
	}
}

// pick is the turn that answers req, and how it was picked.
func (s *Server) pick(req *request) (*Turn, string) {
	for i := range s.script.Side {
		if t := &s.script.Side[i]; t.Match.matches(req, true) {
			return t, fmt.Sprintf("side %d", i)
		}
	}
	s.mu.Lock()
	if s.next < len(s.script.Turns) {
		if t := &s.script.Turns[s.next]; t.Match.matches(req, false) {
			s.next++
			s.mu.Unlock()
			return t, fmt.Sprintf("turn %d", s.next-1)
		}
	}
	s.mu.Unlock()
	text := s.script.SideText
	if text == "" {
		text = "Fake title"
	}
	if req.side() {
		if req.ToolChoice.Type == "tool" {
			for _, tl := range req.Tools {
				if tl.Name == req.ToolChoice.Name {
					return &Turn{Content: []Block{{Type: "tool_use", Name: tl.Name, Input: forcedInput(tl.InputSchema, text)}}}, "canned"
				}
			}
		}
		return &Turn{Content: []Block{{Type: "text", Text: text}}}, "canned"
	}
	return &Turn{Content: []Block{{Type: "text", Text: "fakeapi: no turn of the script matches this request."}}}, "miss"
}

// newID is a new id with prefix, numbered in the order made.
func (s *Server) newID(prefix string) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.ids++
	return fmt.Sprintf("%s%04d", prefix, s.ids)
}

// note keeps and logs a request answered.
func (s *Server) note(r *http.Request, model, answer string) {
	s.mu.Lock()
	s.served = append(s.served, Served{Method: r.Method, Path: r.URL.Path, Model: model, Answer: answer})
	s.mu.Unlock()
	level := slog.LevelInfo
	if answer == "miss" || answer == "not found" || answer == "refused" {
		level = slog.LevelWarn
	}
	s.log.Log(r.Context(), level, "fakeapi", "method", r.Method, "path", r.URL.Path, "model", model, "answer", answer)
}

// models lists the script's models.
func (s *Server) models(w http.ResponseWriter) {
	ids := s.script.Models
	if ids == nil {
		ids = []string{"claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"}
	}
	data := make([]any, 0, len(ids))
	for _, id := range ids {
		data = append(data, model(id))
	}
	var first, last any
	if len(ids) > 0 {
		first, last = ids[0], ids[len(ids)-1]
	}
	writeJSON(w, map[string]any{"data": data, "has_more": false, "first_id": first, "last_id": last})
}

// model is a model as the models API describes one.
func model(id string) map[string]any {
	return map[string]any{"type": "model", "id": id, "display_name": id, "created_at": "2026-01-01T00:00:00Z"}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v) //nolint:errchkjson // maps of plain values; a failed write is the client gone
}

// apiError answers with e, in the API's error shape.
func apiError(w http.ResponseWriter, e *APIError) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(e.Status)
	_ = json.NewEncoder(w).Encode(map[string]any{"type": "error", "error": map[string]any{"type": e.Type, "message": e.Message}}) //nolint:errchkjson // as writeJSON
}
