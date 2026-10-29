package main

import (
	"github.com/afrase/nushi/internal/features/skills"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/skillfile"
)

// newSkills is the Skills view's service: each agent's reader, in the
// order the agents are listed.
func newSkills(known []knownagents.Agent) *skills.Service {
	var order []string
	readers := map[string]skills.Reader{}
	for _, a := range known {
		order = append(order, a.Agent.Name)
		readers[a.Agent.Name] = a.Skills
	}
	return skills.New(order, readers, skillfile.Trash)
}
