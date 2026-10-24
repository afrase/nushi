// Command icongen draws Nushi's icon, "the still lake": broken rings with
// agents riding them and one light at the centre. It writes the Icon Composer
// icon (macOS 26 and later), the PNG icon set older macOS uses, and the bare
// mark. Run it from the repository root: make icons. The app's mark
// (app/lib/mark.dart) draws the same rings.
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const (
	tealTop = "#2F4A57"
	tealBot = "#0F1A20"
	ink     = "#EEF1F5"
	amber   = "#F5A524"
)

// Drawn on a 100-unit grid, centre (50, 50).
type ring struct {
	r, stroke float64
	n         int     // segments
	share     float64 // of each segment's period that's drawn
	rot       float64 // degrees, clockwise from 3 o'clock
}

type bead struct{ r, deg, size float64 }

type detail struct {
	rings    []ring
	beads    []bead
	light    float64
	glow     float64
	pngSizes []int
}

// Full art from 128 px up; thicker lines at 64; one ring at 16 and 32.
var details = []detail{
	{
		rings:    []ring{{31, 2.8, 4, 40 / 48.7, 0}, {19, 2.8, 4, 24 / 29.85, 30}},
		beads:    []bead{{31, 0, 3.8}, {31, 135, 3.8}, {19, -90, 3.2}, {19, 30, 3.2}},
		light:    5.6,
		glow:     12.5,
		pngSizes: []int{1024, 512, 256, 128},
	},
	{
		rings:    []ring{{31, 4.2, 4, 0.78, 0}, {18, 4.2, 4, 0.74, 30}},
		beads:    []bead{{31, 0, 5}, {31, 135, 5}, {18, -90, 4.4}},
		light:    6.5,
		glow:     13,
		pngSizes: []int{64},
	},
	{
		rings:    []ring{{29, 9, 3, 0.74, -60}},
		light:    12,
		pngSizes: []int{32, 16},
	},
}

func main() {
	full := details[0]

	// Icon Composer: the 1024 canvas is the icon's shape.
	icon := "app/macos/Runner/AppIcon.icon"
	s := 10.24
	cx, cy := 50*s, 50*s
	write(icon+"/Assets/lake.svg", svg1024(fmt.Sprintf(`<path d="%s" fill="white"/>`, rings(full, s, 0, 0))))
	write(icon+"/Assets/light.svg", svg1024(fmt.Sprintf(`<path d="%s" fill="white"/>`, circle(cx, cy, full.light*s))))
	write(icon+"/Assets/glow.svg", svg1024(fmt.Sprintf(
		`<defs>%s</defs><circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#glow)"/>`, glowGradient(0.6), cx, cy, full.glow*s)))
	b, err := json.MarshalIndent(iconJSON(), "", "  ")
	check(err)
	write(icon+"/icon.json", string(b)+"\n")

	// The icon set: an 824 body on a 1024 canvas, as Apple's template has it.
	tmp, err := os.MkdirTemp("", "icongen")
	check(err)
	defer os.RemoveAll(tmp)
	set := "app/macos/Runner/Assets.xcassets/AppIcon.appiconset"
	for i, d := range details {
		src := filepath.Join(tmp, fmt.Sprintf("icon%d.svg", i))
		write(src, legacy(d))
		if i == 0 {
			write("docs/brand/icon.svg", legacy(d))
		}
		for _, px := range d.pngSizes {
			out := filepath.Join(set, fmt.Sprintf("app_icon_%d.png", px))
			cmd := exec.Command("sips", "-s", "format", "png", "-z", fmt.Sprint(px), fmt.Sprint(px), src, "--out", out)
			if b, err := cmd.CombinedOutput(); err != nil {
				log.Fatalf("sips: %v\n%s", err, b)
			}
		}
	}

	// The bare mark, for the README.
	write("docs/brand/mark.svg", mark("#15181D"))
	write("docs/brand/mark-dark.svg", mark(ink))
}

func iconJSON() map[string]any {
	return map[string]any{
		"fill-specializations": []any{
			map[string]any{"value": map[string]any{"linear-gradient": []string{srgb(tealTop), srgb(tealBot)}}},
			map[string]any{"appearance": "dark", "value": map[string]any{"linear-gradient": []string{srgb("#1B2B32"), srgb("#070C0F")}}},
		},
		// The first group is on top.
		"groups": []any{
			map[string]any{
				"name": "Light",
				"layers": []any{
					map[string]any{
						"name": "light", "image-name": "light.svg", "glass": false,
						"fill-specializations": []any{
							map[string]any{"value": map[string]any{"solid": srgb(amber)}},
							map[string]any{"appearance": "tinted", "value": "automatic"},
						},
					},
					map[string]any{
						"name": "glow", "image-name": "glow.svg", "glass": false,
						"opacity-specializations": []any{
							map[string]any{"value": 1},
							map[string]any{"appearance": "tinted", "value": 0},
						},
					},
				},
				"shadow":       map[string]any{"kind": "none", "opacity": 0},
				"translucency": map[string]any{"enabled": false, "value": 0},
				"specular":     true,
				"lighting":     "individual",
			},
			map[string]any{
				"name": "Lake",
				"layers": []any{
					map[string]any{
						"name": "lake", "image-name": "lake.svg", "glass": true,
						"fill-specializations": []any{
							map[string]any{"value": map[string]any{"solid": srgb(ink)}},
							map[string]any{"appearance": "tinted", "value": "automatic"},
						},
					},
				},
				"shadow":       map[string]any{"kind": "neutral", "opacity": 0.5},
				"translucency": map[string]any{"enabled": true, "value": 0.25},
				"specular":     true,
				"lighting":     "individual",
			},
		},
		"supported-platforms": map[string]any{"circles": []string{"watchOS"}, "squares": "shared"},
	}
}

func legacy(d detail) string {
	const body, off = 824.0, 100.0
	s := body / 100
	shape := squircle(off, off, body)
	var sb strings.Builder
	sb.WriteString(`<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"><defs>`)
	fmt.Fprintf(&sb, `<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>`, tealTop, tealBot)
	sb.WriteString(glowGradient(0.55))
	sb.WriteString(`</defs>`)
	// A soft shadow from stacked shapes; sips doesn't draw SVG filters.
	for i := 1; i <= 5; i++ {
		fmt.Fprintf(&sb, `<path d="%s" fill="#000" fill-opacity="0.05"/>`, squircle(off-float64(i), off+float64(2*i), body+float64(2*i)))
	}
	fmt.Fprintf(&sb, `<path d="%s" fill="url(#bg)"/>`, shape)
	fmt.Fprintf(&sb, `<path d="%s" fill="none" stroke="#fff" stroke-opacity="0.14" stroke-width="2"/>`, squircle(off+1, off+1, body-2))
	fmt.Fprintf(&sb, `<path d="%s" fill="%s"/>`, rings(d, s, off, off), ink)
	cx, cy := off+50*s, off+50*s
	if d.glow > 0 {
		fmt.Fprintf(&sb, `<circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#glow)"/>`, cx, cy, d.glow*s)
	}
	fmt.Fprintf(&sb, `<path d="%s" fill="%s"/></svg>`+"\n", circle(cx, cy, d.light*s), amber)
	return sb.String()
}

func mark(color string) string {
	d := details[0]
	return fmt.Sprintf(`<svg width="100" height="100" viewBox="12 12 76 76" xmlns="http://www.w3.org/2000/svg"><path d="%s" fill="%s"/><path d="%s" fill="%s"/></svg>`+"\n",
		rings(d, 1, 0, 0), color, circle(50, 50, d.light), amber)
}

// rings returns the rings and beads as one path, scaled by s and moved by (ox, oy).
func rings(d detail, s, ox, oy float64) string {
	cx, cy := ox+50*s, oy+50*s
	var sb strings.Builder
	for _, r := range d.rings {
		period := 360 / float64(r.n)
		// The round caps add half a stroke at each end.
		span := period*r.share - r.stroke/r.r*180/math.Pi
		for k := range r.n {
			a0 := r.rot + float64(k)*period
			sb.WriteString(arc(cx, cy, r.r*s, r.stroke/2*s, a0, a0+span))
		}
	}
	for _, b := range d.beads {
		x, y := at(cx, cy, b.r*s, b.deg)
		sb.WriteString(circle(x, y, b.size*s))
	}
	return sb.String()
}

func at(cx, cy, r, deg float64) (float64, float64) {
	a := deg * math.Pi / 180
	return cx + r*math.Cos(a), cy + r*math.Sin(a)
}

// arc is a ring segment from a0 to a1 degrees, clockwise, with round caps, as
// a filled outline: every shape winds clockwise, so overlaps stay filled.
func arc(cx, cy, r, w, a0, a1 float64) string {
	ro, ri := r+w, r-w
	x0, y0 := at(cx, cy, ro, a0)
	x1, y1 := at(cx, cy, ro, a1)
	x2, y2 := at(cx, cy, ri, a1)
	x3, y3 := at(cx, cy, ri, a0)
	return fmt.Sprintf("M%.2f %.2fA%.2f %.2f 0 0 1 %.2f %.2fA%.2f %.2f 0 0 1 %.2f %.2fA%.2f %.2f 0 0 0 %.2f %.2fA%.2f %.2f 0 0 1 %.2f %.2fZ",
		x0, y0, ro, ro, x1, y1, w, w, x2, y2, ri, ri, x3, y3, w, w, x0, y0)
}

func circle(cx, cy, r float64) string {
	return fmt.Sprintf("M%.2f %.2fa%.2f %.2f 0 1 1 %.2f 0a%.2f %.2f 0 1 1 %.2f 0Z", cx-r, cy, r, r, 2*r, r, r, -2*r)
}

// squircle approximates Apple's icon shape with a superellipse.
func squircle(x, y, size float64) string {
	const n, steps = 4.6, 256
	c := size / 2
	var sb strings.Builder
	for i := range steps {
		t := 2 * math.Pi * float64(i) / steps
		px := c + c*math.Copysign(math.Pow(math.Abs(math.Cos(t)), 2/n), math.Cos(t))
		py := c + c*math.Copysign(math.Pow(math.Abs(math.Sin(t)), 2/n), math.Sin(t))
		cmd := "L"
		if i == 0 {
			cmd = "M"
		}
		fmt.Fprintf(&sb, "%s%.2f %.2f", cmd, x+px, y+py)
	}
	return sb.String() + "Z"
}

func glowGradient(opacity float64) string {
	return fmt.Sprintf(`<radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="%s" stop-opacity="%g"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>`, amber, opacity, amber)
}

func svg1024(body string) string {
	return `<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">` + body + "</svg>\n"
}

func srgb(hex string) string {
	var r, g, b int
	_, err := fmt.Sscanf(hex, "#%02x%02x%02x", &r, &g, &b)
	check(err)
	return fmt.Sprintf("srgb:%.5f,%.5f,%.5f,1.00000", float64(r)/255, float64(g)/255, float64(b)/255)
}

func write(path, text string) {
	check(os.MkdirAll(filepath.Dir(path), 0o755))
	check(os.WriteFile(path, []byte(text), 0o644))
}

func check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
