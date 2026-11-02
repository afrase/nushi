package api

import (
	"context"
	"slices"
	"strings"
	"unicode/utf8"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
)

// A proto3 string must be valid UTF-8 and marshalling fails on one that
// isn't, which fails the call and, in an event, ends the client's Events
// stream. git takes any bytes for a path, a branch or a subject, and a
// file's text is whatever it is; an agent chooses all of them. So what goes
// out is mended here, once for every call and every field to come. That
// suits text, which is only shown. What a client hands back to read something
// (a path, a branch) doesn't get this far: the handlers leave it out with
// sendable, as a mended one names nothing, or something else.

// mended is the interceptor that mends what the API sends.
type mended struct{}

// WrapUnary mends a call's answer.
func (mended) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		resp, err := next(ctx, req)
		if err == nil {
			mendAny(resp.Any())
		}
		return resp, err
	}
}

// WrapStreamingClient leaves a client alone: the API is the server.
func (mended) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	return next
}

// WrapStreamingHandler mends each message a stream sends.
func (mended) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return func(ctx context.Context, conn connect.StreamingHandlerConn) error {
		return next(ctx, mendingConn{conn})
	}
}

// mendingConn is a stream whose messages are mended as they go.
type mendingConn struct{ connect.StreamingHandlerConn }

// Send mends m and sends it.
func (c mendingConn) Send(m any) error {
	mendAny(m)
	return c.StreamingHandlerConn.Send(m)
}

func mendAny(m any) {
	if msg, ok := m.(proto.Message); ok {
		mend(msg.ProtoReflect())
	}
}

// mend replaces what isn't valid UTF-8 in every string of m, nested
// messages included. A message that is valid is only read.
func mend(m protoreflect.Message) {
	m.Range(func(fd protoreflect.FieldDescriptor, v protoreflect.Value) bool {
		switch {
		case fd.IsMap():
			mendMap(v.Map(), fd.MapValue())
		case fd.IsList():
			mendList(v.List(), fd)
		case fd.Message() != nil:
			mend(v.Message())
		case fd.Kind() == protoreflect.StringKind:
			if s, bad := mendedText(v.String()); bad {
				m.Set(fd, protoreflect.ValueOfString(s))
			}
		}
		return true
	})
}

func mendList(list protoreflect.List, fd protoreflect.FieldDescriptor) {
	for i := range list.Len() {
		if fd.Message() != nil {
			mend(list.Get(i).Message())
		} else if fd.Kind() == protoreflect.StringKind {
			if s, bad := mendedText(list.Get(i).String()); bad {
				list.Set(i, protoreflect.ValueOfString(s))
			}
		}
	}
}

// mendMap mends a map's values and keys; a key changes only after the
// walk, which can't be changed under.
func mendMap(m protoreflect.Map, value protoreflect.FieldDescriptor) {
	var keys []protoreflect.MapKey
	m.Range(func(k protoreflect.MapKey, v protoreflect.Value) bool {
		if s, ok := k.Interface().(string); ok && !utf8.ValidString(s) {
			keys = append(keys, k)
		}
		if value.Message() != nil {
			mend(v.Message())
		} else if value.Kind() == protoreflect.StringKind {
			if s, bad := mendedText(v.String()); bad {
				m.Set(k, protoreflect.ValueOfString(s))
			}
		}
		return true
	})
	for _, k := range keys {
		v := m.Get(k)
		m.Clear(k)
		s, _ := mendedText(k.String())
		m.Set(protoreflect.ValueOfString(s).MapKey(), v)
	}
}

// mendedText is s with what isn't valid UTF-8 replaced, and whether
// any was.
func mendedText(s string) (string, bool) {
	if utf8.ValidString(s) {
		return s, false
	}
	return strings.ToValidUTF8(s, "�"), true
}

// sendable says paths and branches can go to a client as they are.
func sendable(names ...string) bool {
	return !slices.ContainsFunc(names, func(s string) bool { return !utf8.ValidString(s) })
}

// sendablePaths is paths without those a client couldn't be sent.
func sendablePaths(paths []string) []string {
	if sendable(paths...) {
		return paths
	}
	return slices.DeleteFunc(slices.Clone(paths), func(p string) bool { return !sendable(p) })
}
