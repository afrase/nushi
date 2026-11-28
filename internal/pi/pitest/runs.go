package pitest

import (
	"encoding/json"
	"slices"
	"strconv"
	"strings"
)

// assistant is the model's message of blocks, as message_end has it: a
// tool call's stops for its use.
func assistant(blocks ...map[string]any) map[string]any {
	stop, raw := "stop", "stop" // raw: the provider's own, an OpenAI-style one's here
	if len(blocks) > 0 && blocks[len(blocks)-1]["type"] == "toolCall" {
		stop, raw = "toolUse", "tool_calls"
	}
	ts := stamp()
	return map[string]any{"role": "assistant", "content": blocks, "api": "fake", "provider": "fake", "model": "m1", "timestamp": ts,
		"stopReason": stop, "responseId": "r" + strconv.FormatInt(ts, 10), "rawStopReason": raw, "durationMs": 2, "thinkingLevel": "off",
		"usage": usage(10, 5, 0, 0)}
}

// usage is a model call's usage as PiG 0.8.0 gives it: the tokens, their
// total (all four added up), what reasoning took, and a cost of each that
// the fake provider doesn't charge.
func usage(input, output, cacheRead, cacheWrite int) map[string]any {
	return map[string]any{"input": input, "output": output, "cacheRead": cacheRead, "cacheWrite": cacheWrite, "reasoning": 0,
		"totalTokens": input + output + cacheRead + cacheWrite,
		"cost":        map[string]any{"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0, "total": 0, "totalFromProvider": false}}
}

// speak streams the model's message m and saves it: as PiG 0.8.0 does,
// message_start with nothing yet ("pending", no responseId), each text's
// and tool call's updates with the usage so far, then message_end with m
// whole. A message whose first block is a thought comes whole with its
// end.
func (p *Program) speak(m map[string]any) {
	start := map[string]any{"role": "assistant", "content": []any{}, "api": m["api"], "provider": m["provider"], "model": m["model"],
		"usage": map[string]any{"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0, "totalTokens": 0, // no reasoning yet
			"cost": map[string]any{"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0, "total": 0}},
		"stopReason": "pending", "timestamp": m["timestamp"]}
	if p.st.Shape == PiG053 { // 0.5.3 named the response at its start
		start["responseId"] = m["responseId"]
	}
	p.emit(map[string]any{"type": "message_start", "message": start})
	update := func(e map[string]any) {
		p.emit(map[string]any{"type": "message_update", "usage": m["usage"], "assistantMessageEvent": e})
	}
	blocks := m["content"].([]map[string]any)
	for i, b := range blocks {
		switch {
		case blocks[0]["type"] == "thinking":
		case b["type"] == "text":
			t := b["text"].(string)
			update(map[string]any{"type": "text_start", "contentIndex": i})
			half := len(t) / 2
			for _, d := range []string{t[:half], t[half:]} {
				update(map[string]any{"type": "text_delta", "contentIndex": i, "delta": d})
			}
			update(map[string]any{"type": "text_end", "contentIndex": i, "content": t})
		case b["type"] == "toolCall":
			args, _ := json.Marshal(b["arguments"])
			update(map[string]any{"type": "toolcall_start", "contentIndex": i, "id": b["id"], "toolName": b["name"]})
			update(map[string]any{"type": "toolcall_delta", "contentIndex": i, "delta": ""})
			update(map[string]any{"type": "toolcall_delta", "contentIndex": i, "delta": string(args)})
			update(map[string]any{"type": "toolcall_end", "contentIndex": i, "toolCall": b})
		}
	}
	p.emit(map[string]any{"type": "message_end", "message": m})
	p.mu.Lock()
	p.append(m)
	p.mu.Unlock()
}

func textBlock(s string) map[string]any { return map[string]any{"type": "text", "text": s} }

// run answers a prompt, by script.
func (p *Program) run(text string) {
	p.emit(map[string]any{"type": "agent_start"})
	p.emit(map[string]any{"type": "turn_start"})
	var msgs []map[string]any        // the run's, for agent_end
	tell := func(m map[string]any) { // a message that comes whole
		p.emit(map[string]any{"type": "message_start", "message": m})
		p.emit(map[string]any{"type": "message_end", "message": m})
		msgs = append(msgs, m)
		p.mu.Lock()
		p.append(m)
		p.mu.Unlock()
	}
	p.mu.Lock()
	first, queued := !p.prompted && p.st.Shape == PiG080, p.queued
	p.prompted, p.queued = true, nil
	select { // what kicked before is in queued
	case <-p.kicked:
	default:
	}
	aborted, settled := p.aborted, p.settled
	p.mu.Unlock()
	if first { // 0.8.0's system message, once per session
		tell(map[string]any{"role": "system", "content": "", "sections": map[string]any{"preamble": "You are a fake."}, "toolsAdded": []any{}, "timestamp": stamp()})
	}
	tell(map[string]any{"role": "user", "content": []map[string]any{textBlock(text)}, "timestamp": stamp()})
	if len(queued) > 0 { // what an abort or an idle steer left queued comes in now, after the prompt
		p.emit(map[string]any{"type": "queue_update", "steering": []string{}, "followUp": []string{}})
		for _, q := range queued {
			tell(map[string]any{"role": "user", "content": []map[string]any{textBlock(q)}, "timestamp": stamp()})
		}
		text += " (and: " + strings.Join(queued, ", ") + ")"
	}
	speak := func(m map[string]any) { // the model's message, streamed; its turn goes on
		p.speak(m)
		msgs = append(msgs, m)
	}
	say := func(m map[string]any) { // the model's message, and its turn ends
		speak(m)
		p.emit(map[string]any{"type": "turn_end", "message": m, "toolResults": []any{}})
	}
	// called ends a turn whose message was call, a tool call, with the
	// tool's result res, and starts the next model call's.
	called := func(call, res map[string]any) {
		p.emit(map[string]any{"type": "message_start", "message": res})
		p.emit(map[string]any{"type": "message_end", "message": res})
		msgs = append(msgs, res)
		p.mu.Lock()
		p.append(res)
		p.mu.Unlock()
		p.emit(map[string]any{"type": "turn_end", "message": call, "toolResults": []any{res}})
		p.emit(map[string]any{"type": "turn_start"})
	}
	var tail []map[string]any    // what comes between agent_end and agent_settled
	settle := func(abort bool) { // at once: an abort or a prompt finds the run running, or settled and said so
		p.mu.Lock()
		defer p.mu.Unlock()
		p.running = false
		p.emit(map[string]any{"type": "agent_end", "messages": msgs, "willRetry": false})
		for _, e := range tail {
			p.emit(e)
		}
		close(settled)
		if p.st.Settles != nil {
			held := make(chan struct{})
			p.mu.Unlock()
			p.st.Settles <- held
			<-held
			p.mu.Lock()
		}
		p.emit(map[string]any{"type": "agent_settled", "aborted": abort})
	}
	switch {
	case strings.Contains(text, "tool"):
		call := map[string]any{"type": "toolCall", "id": "call_1", "name": "bash", "arguments": map[string]any{"command": "ls"}}
		m := assistant(call)
		m["usage"] = usage(10, 5, 0, 96) // the prompt cached, then read by the next call
		speak(m)
		p.emit(map[string]any{"type": "tool_execution_start", "toolCallId": "call_1", "toolName": "bash", "args": call["arguments"]})
		out := map[string]any{"content": []map[string]any{textBlock("a.txt\n")}}
		if p.st.Shape == PiG080 { // no output yet
			p.emit(map[string]any{"type": "tool_execution_update", "toolCallId": "call_1", "toolName": "bash", "args": call["arguments"], "partialResult": map[string]any{"content": []any{}}})
		}
		p.emit(map[string]any{"type": "tool_execution_update", "toolCallId": "call_1", "toolName": "bash", "args": call["arguments"],
			"partialResult": map[string]any{"content": out["content"], "details": map[string]any{}}})
		end := map[string]any{"content": out["content"], "structuredContent": map[string]any{"output": "a.txt\n", "truncated": false, "exit_code": 0, "wall_time_seconds": 0}}
		p.emit(map[string]any{"type": "tool_execution_end", "toolCallId": "call_1", "toolName": "bash", "result": end, "isError": false, "durationMs": 13})
		called(m, map[string]any{"role": "toolResult", "toolCallId": "call_1", "toolName": "bash", "content": out["content"], "isError": false, "durationMs": 13, "timestamp": stamp()})
		done := assistant(textBlock("Done"))
		done["usage"] = usage(10, 5, 96, 0)
		say(done)
	case strings.Contains(text, "todo"): // as Pi's todo and plan-mode extensions keep their lists
		todos := []map[string]any{{"id": 1, "text": "Write tests", "done": true}, {"id": 2, "text": "Ship", "done": false}}
		call := map[string]any{"type": "toolCall", "id": "call_2", "name": "todo", "arguments": map[string]any{"action": "toggle", "id": 1}}
		m := assistant(call)
		speak(m)
		p.emit(map[string]any{"type": "tool_execution_start", "toolCallId": "call_2", "toolName": "todo", "args": call["arguments"]})
		out := map[string]any{"content": []map[string]any{textBlock("Toggled #1")}, "details": map[string]any{"action": "toggle", "todos": todos, "nextId": 3}}
		p.emit(map[string]any{"type": "tool_execution_end", "toolCallId": "call_2", "toolName": "todo", "result": out, "isError": false})
		custom := map[string]any{"type": "custom", "customType": "plan-mode", "data": map[string]any{"todos": []map[string]any{{"step": 1, "text": "Plan it", "completed": false}}}}
		called(m, map[string]any{"role": "toolResult", "toolCallId": "call_2", "toolName": "todo", "content": out["content"], "details": out["details"], "isError": false, "timestamp": stamp()})
		p.mu.Lock()
		p.add(custom)
		p.mu.Unlock()
		p.emit(map[string]any{"type": "entry_appended", "entry": custom})
		say(assistant(textBlock("Done")))
	case strings.Contains(text, "think"):
		m := assistant(map[string]any{"type": "thinking", "thinking": "Hmm."}, textBlock("Thought about it"))
		say(m) // it comes whole, with the message's end
	case strings.Contains(text, "fail"):
		m := assistant()
		m["stopReason"], m["errorMessage"] = "error", "boom"
		say(m)
	case strings.Contains(text, "garbage"):
		p.wmu.Lock()
		_, _ = p.w.Write([]byte("not json\n"))
		p.wmu.Unlock()
		p.emit(map[string]any{"type": "mystery"})
		say(assistant(textBlock("Still here")))
	case strings.Contains(text, "long"):
		m := assistant(textBlock("cut"))
		m["stopReason"] = "length"
		say(m)
		edit := map[string]any{"type": "context_edit", "targetId": p.leaf, "replacement": nil}
		p.mu.Lock()
		p.add(edit)
		p.mu.Unlock()
		tail = append(tail, map[string]any{"type": "entry_appended", "entry": edit})
	case strings.Contains(text, "hold"):
		p.st.waiting(text)
		<-aborted
		say(p.held(tell))
		settle(true)
		return
	case strings.Contains(text, "deaf"):
		p.st.waiting(text)
		<-p.gone
		return
	case strings.Contains(text, "listen"):
		p.st.waiting(text)
		if s, ok := p.steer(aborted); ok { // taken as the user's; the run goes on
			tell(map[string]any{"role": "user", "content": []map[string]any{textBlock(s)}, "timestamp": stamp()})
			p.st.waiting(text)
			<-aborted
		}
		m := assistant()
		m["stopReason"], m["errorMessage"] = "aborted", "Request was aborted"
		say(m)
		settle(true)
		return
	case strings.Contains(text, "wait"):
		p.st.waiting(text)
		s, ok := p.steer(aborted)
		if !ok {
			m := assistant()
			m["stopReason"], m["errorMessage"] = "aborted", "Request was aborted"
			say(m)
			settle(true)
			return
		}
		tell(map[string]any{"role": "user", "content": []map[string]any{textBlock(s)}, "timestamp": stamp()}) // before the next model call
		say(assistant(textBlock("Steered: " + s)))
	default:
		say(assistant(textBlock("You said: " + text)))
	}
	settle(false)
}

// steer waits for the run's next steer and takes it from the queue
// (false once aborted first), with a queue_update of what is left.
func (p *Program) steer(aborted chan struct{}) (string, bool) {
	for {
		select {
		case <-aborted:
			return "", false
		case <-p.kicked:
		}
		p.mu.Lock()
		if len(p.queued) > 0 { // else clear_queue took it back
			s := p.queued[0]
			p.queued = p.queued[1:]
			p.emit(map[string]any{"type": "queue_update", "steering": slices.Clone(p.queued), "followUp": []string{}})
			p.mu.Unlock()
			return s, true
		}
		p.mu.Unlock()
	}
}

// held is how a "hold" run ends, aborted: what was steered into it stays
// queued for the next run (0.8.0), or comes in now as the user's, and
// the model call it starts fails (0.5.3).
func (p *Program) held(tell func(map[string]any)) map[string]any {
	m := assistant()
	m["stopReason"], m["errorMessage"] = "aborted", "Request was aborted"
	if p.st.Shape == PiG080 {
		return m
	}
	p.mu.Lock()
	steers := p.queued
	p.queued = nil
	if len(steers) > 0 {
		p.emit(map[string]any{"type": "queue_update", "steering": []string{}, "followUp": []string{}})
	}
	p.mu.Unlock()
	for _, st := range steers {
		tell(map[string]any{"role": "user", "content": []map[string]any{textBlock(st)}, "timestamp": stamp()})
	}
	if len(steers) > 0 {
		m["stopReason"], m["errorMessage"] = "error", "This operation was aborted"
	}
	return m
}
