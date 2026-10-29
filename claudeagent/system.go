package claudeagent

// The system messages: type "system", each subtype its own type. Each has
// the fields a client acts on; Raw has the rest.

var systemDecoders = map[string]func() Message{}
