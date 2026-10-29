package sessions

import (
	"bytes"
	"encoding/json"
	"errors"
)

// object is a JSON object that keeps its keys in order and its values as
// written, so a record Fork copies reads as the CLI wrote it, fields this
// package doesn't know included.
type object struct {
	keys []string
	vals map[string]json.RawMessage
}

// parseObject reads one JSON object; a key given twice keeps its first
// place and its last value, as JSON.parse does.
func parseObject(data []byte) (*object, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	if tok, err := dec.Token(); err != nil || tok != json.Delim('{') {
		return nil, errors.New("not a JSON object")
	}
	o := &object{vals: map[string]json.RawMessage{}}
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return nil, err
		}
		key, _ := tok.(string) // an object's tokens here are always keys
		var v json.RawMessage
		if err := dec.Decode(&v); err != nil {
			return nil, err
		}
		o.put(key, v)
	}
	if _, err := dec.Token(); err != nil {
		return nil, err
	}
	if dec.More() {
		return nil, errors.New("more after the JSON object")
	}
	return o, nil
}

// ordered makes an object of key-value pairs, in that order.
func ordered(kv ...any) *object {
	o := &object{vals: map[string]json.RawMessage{}}
	for i := 0; i+1 < len(kv); i += 2 {
		key, _ := kv[i].(string)
		o.set(key, kv[i+1])
	}
	return o
}

// encode is ordered(kv...) as a line of JSON.
func encode(kv ...any) string { return string(ordered(kv...).encode()) }

func (o *object) put(key string, v json.RawMessage) {
	if _, ok := o.vals[key]; !ok {
		o.keys = append(o.keys, key)
	}
	o.vals[key] = v
}

// set sets key to v, in its place when the object has it, else last.
func (o *object) set(key string, v any) {
	if inner, ok := v.(*object); ok {
		o.put(key, inner.encode())
		return
	}
	o.put(key, marshal(v))
}

func (o *object) remove(key string) {
	if _, ok := o.vals[key]; !ok {
		return
	}
	delete(o.vals, key)
	for i, k := range o.keys {
		if k == key {
			o.keys = append(o.keys[:i], o.keys[i+1:]...)
			break
		}
	}
}

// encode writes the object compactly, without HTML escapes (the CLI
// writes JSON.stringify's).
func (o *object) encode() []byte {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, k := range o.keys {
		if i > 0 {
			b.WriteByte(',')
		}
		b.Write(marshal(k))
		b.WriteByte(':')
		if err := json.Compact(&b, o.vals[k]); err != nil {
			b.WriteString("null") // never: values were read as JSON or marshalled
		}
	}
	b.WriteByte('}')
	return b.Bytes()
}

// marshal encodes v as JSON without HTML escapes.
func marshal(v any) json.RawMessage {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return json.RawMessage("null") // never: only strings, objects and values read as JSON
	}
	return bytes.TrimSuffix(b.Bytes(), []byte("\n"))
}

// unmarshalOK decodes raw into v and says whether it could.
func unmarshalOK(raw json.RawMessage, v any) bool { return json.Unmarshal(raw, v) == nil }
