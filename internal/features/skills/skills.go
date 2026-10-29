// Package skills shows the skills each agent uses in a folder and changes
// them the ways the agent documents (ADRs 0051, 0052). The agents' own
// files are the source of truth; Nushi keeps no copy. Each agent has a
// Reader (internal/claudeskills, codexskills, piskills); the skills in a
// repository's .agents/skills, which several agents read, are "shared":
// listed once, with the agents that load them, each agent's switch its
// own.
package skills

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// Reader is one agent's skills.
type Reader interface {
	// List is the agent's skills in folder, the shared ones it loads
	// among them (Source "shared"; or would load once the folder is
	// trusted: State "untrusted"), each with its state for the agent.
	List(ctx context.Context, folder string) (model.Skills, error)
	// SetSkillOn turns one of its skills on or off, found by its source
	// and name among those it lists for folder.
	SetSkillOn(ctx context.Context, folder, source, name string, on bool) error
	// Trash moves one of its own skills' folders to the Trash (shared
	// ones go through Service.Trash).
	Trash(ctx context.Context, folder, path string) error
}

// SharedReader is an agent that loads shared skills it doesn't list as
// shared (Claude, through links of its own until it reads .agents/skills).
// Shared is those skills in folder, each with its state for the agent and
// the link as its one Agents entry's Via. For any other agent the shared
// skills are those its List gives.
type SharedReader interface {
	Shared(ctx context.Context, folder string) []model.Skill
}

// Plugins is an agent's plugins (Claude's).
type Plugins interface {
	SetPluginOn(ctx context.Context, folder, id string, on bool) error
	Uninstall(ctx context.Context, folder, id string) error
	// PluginScope is where SetPluginOn changes a plugin for folder:
	// "user" (everywhere) or "local" (this project).
	PluginScope(folder string, p model.Plugin) string
}

// BuiltIn is an agent whose built-in skills go on and off together
// (Claude's).
type BuiltIn interface {
	SetBuiltInOn(ctx context.Context, folder string, on bool) error
}

// Linker is an agent that can be given a shared skill it doesn't read by
// a link of its own (Claude, until it reads .agents/skills).
type Linker interface {
	Link(ctx context.Context, folder, path string) error
}

// Service is the skills of every agent Nushi runs.
type Service struct {
	readers map[string]Reader
	order   []string // the agents' names, as the app lists them
	// trash moves a shared skill's folder to the Trash, only right in one
	// of the project's roots or yours (skillfile.Trash).
	trash func(ctx context.Context, project, yours []string, path string) error
}

// New takes each agent's reader, in the order the agents are listed, and
// what moves a shared skill's folder to the Trash (skillfile.Trash).
func New(order []string, readers map[string]Reader, trash func(ctx context.Context, project, yours []string, path string) error) *Service {
	return &Service{readers: readers, order: order, trash: trash}
}

func absolute(folder string) error {
	if !filepath.IsAbs(folder) || filepath.Clean(folder) != folder {
		return fmt.Errorf("%q is not an absolute folder", folder)
	}
	return nil
}

// reader is agent's reader; "" is Claude's (an app before API 67).
func (s *Service) reader(agent string) (Reader, error) {
	if r, ok := s.readers[cmp.Or(agent, "claude")]; ok {
		return r, nil
	}
	return nil, fmt.Errorf("Nushi doesn't know %q's skills", agent)
}

// List returns agent's skills and plugins in folder. Its shared skills,
// and those other agents load from the shared folders, come with every
// agent that loads each; a skill of the agent's that is a link to a shared
// one shows as that one.
func (s *Service) List(ctx context.Context, agent, folder string) (model.Skills, error) {
	if err := absolute(folder); err != nil {
		return model.Skills{}, err
	}
	r, err := s.reader(agent)
	if err != nil {
		return model.Skills{NoSkills: "Nushi doesn't know where this agent keeps skills."}, nil //nolint:nilerr // said in the list
	}
	out, err := r.List(ctx, folder)
	if err != nil {
		return out, err
	}
	shared := s.shared(ctx, folder, map[string]model.Skills{cmp.Or(agent, "claude"): out})
	vias := map[string]bool{}
	for _, sk := range shared {
		for _, a := range sk.Agents {
			vias[a.Via] = a.Via != ""
		}
	}
	out.Skills = slices.DeleteFunc(out.Skills, func(sk model.Skill) bool { return sk.Source == "shared" || vias[sk.Path] })
	out.Skills = append(out.Skills, shared...)
	return out, nil
}

// shared is every shared skill some agent loads in folder, by path (its
// root's links resolved: agents spell the folder differently), with the
// agents that load it, in the agents' order. lists are agents' lists
// already read.
func (s *Service) shared(ctx context.Context, folder string, lists map[string]model.Skills) []model.Skill {
	var out []model.Skill
	for _, name := range s.order {
		for _, sk := range s.sharedOf(ctx, name, folder, lists) {
			sk.Path = filepath.Join(git.RealPath(filepath.Dir(sk.Path)), filepath.Base(sk.Path))
			i := slices.IndexFunc(out, func(o model.Skill) bool { return o.Path == sk.Path })
			if i < 0 {
				i = len(out)
				base := sk
				base.Source, base.State, base.SetIn, base.Agents = "shared", "on", "", nil
				out = append(out, base)
			}
			a := model.SkillAgent{Agent: name, State: sk.State, SetIn: sk.SetIn}
			if len(sk.Agents) == 1 {
				a.Via = sk.Agents[0].Via
			}
			out[i].Agents = append(out[i].Agents, a)
		}
	}
	// The project's first, nearest first, then yours; by name in a folder.
	slices.SortStableFunc(out, func(a, b model.Skill) int {
		if a.Everywhere != b.Everywhere {
			return map[bool]int{true: 1, false: -1}[a.Everywhere]
		}
		return cmp.Or(cmp.Compare(len(filepath.Dir(b.Path)), len(filepath.Dir(a.Path))), cmp.Compare(a.Name, b.Name))
	})
	return out
}

// sharedOf is the shared skills agent name loads in folder: its
// SharedReader's, else the shared ones its list has (from lists when read
// already; what a list that fails gives still counts).
func (s *Service) sharedOf(ctx context.Context, name, folder string, lists map[string]model.Skills) []model.Skill {
	r := s.readers[name]
	if sr, ok := r.(SharedReader); ok {
		return sr.Shared(ctx, folder)
	}
	l, ok := lists[name]
	if !ok {
		l, _ = r.List(ctx, folder)
	}
	var out []model.Skill
	for _, sk := range l.Skills {
		if sk.Source == "shared" {
			out = append(out, sk)
		}
	}
	return out
}

// The changes run to the end once begun, even if the app goes: a CLI
// killed while it writes an agent's settings could leave them half
// written.

// SetSkillOn turns one of agent's skills on or off: source "user",
// "project" or "shared" (by name), or "builtin" (name empty) for its
// built-in skills together.
func (s *Service) SetSkillOn(ctx context.Context, agent, folder, source, name string, on bool) error {
	ctx = context.WithoutCancel(ctx)
	if err := absolute(folder); err != nil {
		return err
	}
	r, err := s.reader(agent)
	if err != nil {
		return err
	}
	switch source {
	case "builtin":
		if b, ok := r.(BuiltIn); ok {
			return b.SetBuiltInOn(ctx, folder, on)
		}
	case "user", "project", "shared", "system":
		return r.SetSkillOn(ctx, folder, source, name, on)
	case "plugin":
		return errors.New("a plugin's skills go on and off with their plugin")
	}
	return fmt.Errorf("no skills come from %q", source)
}

// plugins is agent's plugins, if it has any.
func (s *Service) plugins(agent string) (Plugins, error) {
	r, err := s.reader(agent)
	if err != nil {
		return nil, err
	}
	if p, ok := r.(Plugins); ok {
		return p, nil
	}
	return nil, fmt.Errorf("Nushi doesn't manage %s's plugins", agent)
}

// PluginScope is where a plugin's switch acts for folder.
func (s *Service) PluginScope(agent, folder string, p model.Plugin) string {
	if ps, err := s.plugins(agent); err == nil {
		return ps.PluginScope(folder, p)
	}
	return ""
}

func (s *Service) SetPluginOn(ctx context.Context, agent, folder, id string, on bool) error {
	if err := absolute(folder); err != nil {
		return err
	}
	p, err := s.plugins(agent)
	if err != nil {
		return err
	}
	return p.SetPluginOn(context.WithoutCancel(ctx), folder, id, on)
}

func (s *Service) Uninstall(ctx context.Context, agent, folder, id string) error {
	if err := absolute(folder); err != nil {
		return err
	}
	p, err := s.plugins(agent)
	if err != nil {
		return err
	}
	return p.Uninstall(context.WithoutCancel(ctx), folder, id)
}

// Trash moves a skill's folder to the Trash: one of agent's own, or a
// shared one some agent lists (with every link to it an agent lists,
// which would point at nothing after).
func (s *Service) Trash(ctx context.Context, agent, folder, path string) error {
	ctx = context.WithoutCancel(ctx)
	if err := absolute(folder); err != nil {
		return err
	}
	shared := s.shared(ctx, folder, nil)
	i := slices.IndexFunc(shared, func(sk model.Skill) bool { return sk.Path == path })
	if i < 0 {
		r, err := s.reader(agent)
		if err != nil {
			return err
		}
		return r.Trash(ctx, folder, path)
	}
	for _, a := range shared[i].Agents {
		if a.Via != "" {
			if err := s.readers[a.Agent].Trash(ctx, folder, a.Via); err != nil {
				return err
			}
		}
	}
	if shared[i].Everywhere {
		return s.trash(ctx, nil, []string{filepath.Dir(path)}, path)
	}
	return s.trash(ctx, []string{filepath.Dir(path)}, nil, path)
}

// Link gives agent a shared skill it doesn't load by a link of its own
// (Claude's .claude/skills/<name>): only a shared skill some agent lists
// here.
func (s *Service) Link(ctx context.Context, agent, folder, path string) error {
	if err := absolute(folder); err != nil {
		return err
	}
	r, err := s.reader(agent)
	if err != nil {
		return err
	}
	l, ok := r.(Linker)
	if !ok {
		return fmt.Errorf("Nushi doesn't link skills for %s", agent)
	}
	if !slices.ContainsFunc(s.shared(ctx, folder, nil), func(sk model.Skill) bool { return sk.Path == path }) {
		return fmt.Errorf("%s isn't a shared skill here", path)
	}
	return l.Link(ctx, folder, path)
}
