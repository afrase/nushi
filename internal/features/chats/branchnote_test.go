package chats

import "testing"

// A replayed user's message loses the note that went before it: a block
// of its own, or run into the user's text; nothing else.
func TestUnnoted(t *testing.T) {
	note := branchNote("nushi/brave-otter", "nushi/bump-go-1-27-3")
	if note != "[Nushi] This worktree's branch was renamed from nushi/brave-otter to nushi/bump-go-1-27-3. Use the new name." {
		t.Errorf("the note: %q", note)
	}
	for in, want := range map[string]string{
		note:                       "",
		note + "go on":             "go on",
		note + "\n\ngo on\n":       "go on\n",
		"go on " + note:            "go on " + note,
		"[Nushi] This worktree's":  "[Nushi] This worktree's",
		"plain\n" + note + "\nend": "plain\n" + note + "\nend",
	} {
		got, ok := unnoted(in)
		if got != want || ok != (got != in) {
			t.Errorf("unnoted(%q) = %q, %v; want %q", in, got, ok, want)
		}
	}
}
