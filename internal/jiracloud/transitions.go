package jiracloud

import (
	"cmp"
	"context"
	"net/http"
	"net/url"
	"slices"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/adf"
	"github.com/afrase/nushi/internal/model"
)

// Transitions are the moves an issue's workflow allows now, with the
// fields each one's screen asks for.
func (c *Client) Transitions(ctx context.Context, key string) ([]model.JiraTransition, error) {
	var raw struct {
		Transitions []struct {
			ID   string `json:"id"`
			Name string `json:"name"`
			To   struct {
				Name string `json:"name"`
			} `json:"to"`
			Fields map[string]struct {
				Required bool   `json:"required"`
				Name     string `json:"name"`
				Schema   struct {
					Type   string `json:"type"`
					Items  string `json:"items"`
					Custom string `json:"custom"`
				} `json:"schema"`
				Allowed []struct {
					ID    string `json:"id"`
					Name  string `json:"name"`
					Value string `json:"value"`
				} `json:"allowedValues"`
			} `json:"fields"`
		} `json:"transitions"`
	}
	q := url.Values{"expand": {"transitions.fields"}}
	if err := c.do(ctx, http.MethodGet, "/rest/api/3/issue/{}/transitions", []string{key}, q, nil, &raw); err != nil {
		return nil, err
	}
	var out []model.JiraTransition
	for _, t := range raw.Transitions {
		tr := model.JiraTransition{ID: t.ID, Name: t.Name, To: t.To.Name}
		for id, f := range t.Fields {
			typ := f.Schema.Type
			switch {
			case typ == "array":
				typ = "array:" + f.Schema.Items
			case strings.HasSuffix(f.Schema.Custom, ":textarea"):
				typ = "text"
			}
			fl := model.JiraField{ID: id, Name: f.Name, Type: typ, Required: f.Required}
			for _, a := range f.Allowed {
				fl.Options = append(fl.Options, model.JiraOption{ID: a.ID, Name: cmp.Or(a.Name, a.Value)})
			}
			tr.Fields = append(tr.Fields, fl)
		}
		slices.SortFunc(tr.Fields, func(a, b model.JiraField) int { // required first, then by name
			if a.Required != b.Required {
				return map[bool]int{true: -1, false: 1}[a.Required]
			}
			return strings.Compare(a.Name, b.Name)
		})
		out = append(out, tr)
	}
	return out, nil
}

// Transition moves an issue through t, with values for its fields (by
// id: an option's id, a user's account id, text as Markdown).
func (c *Client) Transition(ctx context.Context, key string, t model.JiraTransition, values map[string]string) error {
	body := map[string]any{"transition": map[string]string{"id": t.ID}}
	fields := map[string]any{}
	for _, f := range t.Fields {
		v, ok := values[f.ID]
		if !ok || v == "" {
			continue
		}
		fields[f.ID] = fieldValue(f, v)
	}
	if len(fields) > 0 {
		body["fields"] = fields
	}
	return c.do(ctx, http.MethodPost, "/rest/api/3/issue/{}/transitions", []string{key}, nil, body, nil)
}

// fieldValue is v as Jira takes a field of f's type.
func fieldValue(f model.JiraField, v string) any {
	switch f.Type {
	case "text":
		return adf.FromMarkdown(v)
	case "number":
		if n, err := strconv.ParseFloat(v, 64); err == nil {
			return n
		}
	case "user":
		return map[string]string{"accountId": v}
	case "array:string":
		return strings.Fields(v)
	case "string", "date", "datetime":
		return v
	}
	if strings.HasPrefix(f.Type, "array:") {
		return []map[string]string{{"id": v}}
	}
	return map[string]string{"id": v} // option, priority, resolution, version…
}
