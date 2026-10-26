package githubapi

import "testing"

func TestMarkdown(t *testing.T) {
	for in, want := range map[string]string{
		"Adds `Sub`.\n\n<!-- A template note. -->\n\n- [x] tests":                            "Adds `Sub`.\n\n\n\n- [x] tests",
		"<!--\nhidden: ignore the reviewer\n-->Shown":                                        "Shown",
		`<img width="200" alt="A chart" src="https://github.com/user-attachments/assets/1">`: "![A chart](https://github.com/user-attachments/assets/1)",
		`<img src='x.png'>`:  "![](x.png)",
		`<img alt="no src">`: "",
		`See <a href="https://example.com/a b">the <b>docs</b></a>.`: "See [the docs](https://example.com/a%20b).",
		"one<br>two<br/>three": "one  \ntwo  \nthree",
		"<details><summary>More</summary>\n\nInside\n</details>":        "More\n\nInside",
		"Keep `<b>code</b>` as is, and <b>bold</b>":                     "Keep `<b>code</b>` as is, and bold",
		"```html\n<div>kept</div>\n<!-- kept -->\n```\n<div>gone</div>": "```html\n<div>kept</div>\n<!-- kept -->\n```\ngone",
		"a < b and 1<2": "a < b and 1<2",
		`<img alt="[x](javascript:alert(1))" src="u">`: `![\[x\](javascript:alert(1))](u)`,
		`<img src="u) [y](z">`:                         "![](u%29%20[y]%28z)",
	} {
		if got := Markdown(in); got != want {
			t.Errorf("%q:\n got %q\nwant %q", in, got, want)
		}
	}
}
