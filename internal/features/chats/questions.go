package chats

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strconv"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// CreateElicitation shows the agent's form as a question and waits for the
// user's answer.
func (c *chat) CreateElicitation(ctx context.Context, req acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	if req.Mode != "form" || req.RequestedSchema == nil {
		return nil, fmt.Errorf("unsupported elicitation mode %q", req.Mode)
	}
	fields, err := formFields(req.RequestedSchema)
	if err != nil {
		return nil, err
	}
	answer := make(chan []model.Field, 1)
	c.mu.Lock()
	id := c.addLocked(model.Item{Kind: model.Question, Status: "pending", Text: req.Message, Fields: fields})
	c.questions[id] = answer
	c.mu.Unlock()

	var answered []model.Field
	var ok bool
	select {
	case answered, ok = <-answer:
	case <-ctx.Done():
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.questions, id)
	it := c.itemLocked(id)
	switch {
	case !ok:
		it.Status = "cancelled"
	case answered == nil:
		it.Status = "declined"
	default:
		it.Status, it.Fields = "answered", answered
	}
	c.publishLocked(*it)
	switch it.Status {
	case "cancelled":
		return &acp.CreateElicitationResponse{Action: "cancel"}, nil
	case "declined":
		return &acp.CreateElicitationResponse{Action: "decline"}, nil
	}
	content, err := formContent(answered)
	if err != nil {
		return nil, err
	}
	return &acp.CreateElicitationResponse{Action: "accept", Content: content}, nil
}

// AnswerQuestion sends the user's answer to a pending question: values by
// field id, or nil to decline it.
func (s *Service) AnswerQuestion(chatID, itemID string, values map[string][]string) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	answer := c.questions[itemID]
	if answer == nil {
		return fmt.Errorf("no pending question %q", itemID)
	}
	var fields []model.Field
	if values != nil {
		fields = slices.Clone(c.itemLocked(itemID).Fields)
		for i := range fields {
			fields[i].Values = values[fields[i].ID]
			if err := check(fields[i]); err != nil {
				return err
			}
		}
	}
	delete(c.questions, itemID)
	answer <- fields
	return nil
}

func check(f model.Field) error {
	switch {
	case f.Required && len(f.Values) == 0:
		return fmt.Errorf("%q needs an answer", f.Title)
	case len(f.Values) > 1 && f.Type != model.Choices:
		return fmt.Errorf("%q takes one answer", f.Title)
	}
	for _, v := range f.Values {
		if (f.Type == model.Choice || f.Type == model.Choices) &&
			!slices.ContainsFunc(f.Options, func(o model.Option) bool { return o.ID == v }) {
			return fmt.Errorf("%q has no option %q", f.Title, v)
		}
	}
	return nil
}

// formFields reads the form's properties, in their order.
func formFields(schema *acp.ElicitationSchema) ([]model.Field, error) {
	dec := json.NewDecoder(bytes.NewReader(schema.Properties))
	if _, err := dec.Token(); err != nil { // {
		return nil, fmt.Errorf("elicitation schema: %w", err)
	}
	var fields []model.Field
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return nil, fmt.Errorf("elicitation schema: %w", err)
		}
		var p acp.ElicitationPropertySchema
		if err := dec.Decode(&p); err != nil {
			return nil, fmt.Errorf("elicitation schema: %w", err)
		}
		id := tok.(string)
		f := model.Field{ID: id, Required: slices.Contains(schema.Required, id)}
		switch {
		case p.String != nil:
			f.Title, f.Description, f.Type = p.String.Title, p.String.Description, model.Text
			f.Options = enumOptions(p.String.OneOf, p.String.Enum)
			if f.Options != nil {
				f.Type = model.Choice
			}
		case p.Array != nil:
			f.Title, f.Description, f.Type = p.Array.Title, p.Array.Description, model.Choices
			if it := p.Array.Items; it.String != nil {
				f.Options = enumOptions(nil, it.String.Enum)
			} else if it.TitledMultiSelectItems != nil {
				f.Options = enumOptions(it.TitledMultiSelectItems.AnyOf, nil)
			}
		case p.Number != nil:
			f.Title, f.Description, f.Type = p.Number.Title, p.Number.Description, model.Number
		case p.Integer != nil:
			f.Title, f.Description, f.Type = p.Integer.Title, p.Integer.Description, model.Integer
		case p.Boolean != nil:
			f.Title, f.Description, f.Type = p.Boolean.Title, p.Boolean.Description, model.Boolean
		default:
			return nil, fmt.Errorf("elicitation field %q has unsupported type %q", id, p.Type)
		}
		fields = append(fields, f)
	}
	return fields, nil
}

func enumOptions(titled []acp.EnumOption, plain []string) []model.Option {
	var out []model.Option
	for _, o := range titled {
		out = append(out, model.Option{ID: o.Const, Name: o.Title, Description: o.Description})
	}
	for _, v := range plain {
		out = append(out, model.Option{ID: v, Name: v})
	}
	return out
}

// formContent encodes the answered fields as the form's content; unanswered
// fields are left out.
func formContent(fields []model.Field) (json.RawMessage, error) {
	content := map[string]any{}
	for _, f := range fields {
		if len(f.Values) == 0 {
			continue
		}
		v := f.Values[0]
		var err error
		switch f.Type {
		case model.Choices:
			content[f.ID] = f.Values
		case model.Number:
			content[f.ID], err = strconv.ParseFloat(v, 64)
		case model.Integer:
			content[f.ID], err = strconv.ParseInt(v, 10, 64)
		case model.Boolean:
			content[f.ID], err = strconv.ParseBool(v)
		default:
			content[f.ID] = v
		}
		if err != nil {
			return nil, fmt.Errorf("%q: %w", f.Title, err)
		}
	}
	return json.Marshal(content)
}
