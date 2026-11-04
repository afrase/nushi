// Package fakeapi is a fake Anthropic Messages API, for recording the
// real claude with no login: claude's ANTHROPIC_BASE_URL points at it,
// with any dummy key. Each request for a reply is answered by the next
// turn of a Script, streamed as server-sent events in the API's shapes;
// claude's other calls (counting tokens, listing models, its small
// requests of its own such as a title) get canned answers.
//
// It never needs a key, and refuses one that looks like a real Anthropic
// key, so a recording can't run on someone's account by mistake. It
// keeps no request's content: what it logs is each call's path, model and
// how it was answered.
package fakeapi
