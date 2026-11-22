package claudeskills

import (
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// The skills shared through ~/.agents/skills and ~/.claude are looked for
// in the home folder, which must be the test's, never the user's.
func TestMain(m *testing.M) { testcheck.Main(m) }
