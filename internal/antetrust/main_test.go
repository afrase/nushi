package antetrust

import (
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// What a folder brings Ante is looked for up to the home folder (~/.ante),
// which must be the test's, never the user's.
func TestMain(m *testing.M) { testcheck.Main(m) }
