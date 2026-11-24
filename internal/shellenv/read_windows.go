package shellenv

import (
	"context"
	"errors"
	"fmt"
	"time"

	"golang.org/x/sys/windows/registry"
)

// source is what Status names the reading after. Windows has no login
// shell: the environment a new terminal gets is the registry's, which the
// app shows as Windows's.
func source(string) string { return "Windows" }

// The registry's environment keys: the system's, and the user's own.
const (
	systemEnvKey = `SYSTEM\CurrentControlSet\Control\Session Manager\Environment`
	userEnvKey   = `Environment`
)

// Read is the environment Windows gives a new process, from the
// registry as it is now (combine): a variable or Path changed since the
// daemon started is in it, as in a terminal opened then. Nothing runs, so
// shell and timeout don't apply. The user's key may be missing; the
// system's must be there.
// Windows has no umask or open-files limit: Limits is always empty.
func Read(_ context.Context, _ string, env []string, _ time.Duration) ([]string, Limits, error) {
	system, err := registryVars(registry.LOCAL_MACHINE, systemEnvKey)
	if err != nil {
		return nil, Limits{}, fmt.Errorf("the system's variables couldn't be read (%w)", err)
	}
	user, err := registryVars(registry.CURRENT_USER, userEnvKey)
	if err != nil && !errors.Is(err, registry.ErrNotExist) {
		return nil, Limits{}, fmt.Errorf("your variables couldn't be read (%w)", err)
	}
	return combine(system, user, env), Limits{}, nil
}

// ReadLogin has nothing to fall back on: Read runs no shell.
func ReadLogin(context.Context, string, []string, time.Duration) ([]string, Limits, error) {
	return nil, Limits{}, errors.ErrUnsupported
}

// kept is base: the registry's environment is laid over the daemon's,
// and unsets nothing of it.
func kept(base, _ []string) []string { return base }

// registryVars are the string values of the key at path under root, in
// the registry's order; one of another type (a number, binary) isn't a
// variable and is passed over.
func registryVars(root registry.Key, path string) ([]registryVar, error) {
	k, err := registry.OpenKey(root, path, registry.QUERY_VALUE)
	if err != nil {
		return nil, err
	}
	defer func() { _ = k.Close() }()
	names, err := k.ReadValueNames(0)
	if err != nil {
		return nil, err
	}
	vars := make([]registryVar, 0, len(names))
	for _, name := range names {
		value, kind, err := k.GetStringValue(name)
		if err != nil {
			continue // not a string, or gone since it was listed
		}
		vars = append(vars, registryVar{name: name, value: value, expand: kind == registry.EXPAND_SZ})
	}
	return vars, nil
}
