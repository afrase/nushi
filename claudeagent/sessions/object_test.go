package sessions

import "testing"

func TestObjectKeepsTheRecord(t *testing.T) {
	o, err := parseObject([]byte(` {"type":"user", "b": [1, 2],"a":{"x":"<&>"},"b":3,"c":"é"} `))
	if err != nil {
		t.Fatal(err)
	}
	o.set("a", "new <a>")
	o.set("z", struct {
		K int `json:"k"`
		J any `json:"j"`
	}{1, nil})
	o.remove("c")
	o.remove("missing")
	if got, want := string(o.encode()), `{"type":"user","b":3,"a":"new <a>","z":{"k":1,"j":null}}`; got != want {
		t.Errorf("encode = %s\nwant %s", got, want)
	}
	for _, bad := range []string{``, `[1]`, `"x"`, `{"a":1`, `{"a":1} {}`, `{"a":}`} {
		if _, err := parseObject([]byte(bad)); err == nil {
			t.Errorf("parseObject(%q) took it", bad)
		}
	}
	if got := string(marshal(titleRecord{Type: "custom-title", CustomTitle: "a&b"})); got !=
		`{"type":"custom-title","sessionId":"","customTitle":"a&b","uuid":"","timestamp":""}` {
		t.Errorf("marshal = %s", got)
	}
}
