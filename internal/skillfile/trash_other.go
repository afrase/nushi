//go:build !darwin && !linux

package skillfile

// TrashProgram is none on this OS (ADR 0097): Trash answers
// errors.ErrUnsupported.
var TrashProgram []string
