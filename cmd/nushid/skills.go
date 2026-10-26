package main

import (
	"github.com/afrase/nushi/internal/anteskills"
	"github.com/afrase/nushi/internal/claudeskills"
	"github.com/afrase/nushi/internal/codexskills"
	"github.com/afrase/nushi/internal/features/skills"
	"github.com/afrase/nushi/internal/ompskills"
	"github.com/afrase/nushi/internal/pigskills"
	"github.com/afrase/nushi/internal/skillfile"
)

// newSkills is the Skills view's service: each agent's reader, in the
// order the agents are listed.
func newSkills() *skills.Service {
	return skills.New([]string{"claude", "codex", "ante", "omp", "pig"}, map[string]skills.Reader{
		"claude": claudeskills.Claude{}, "codex": codexskills.Codex{}, "ante": anteskills.Ante{},
		"omp": ompskills.OMP{}, "pig": pigskills.PiG{},
	}, skillfile.Trash)
}
