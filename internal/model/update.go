package model

import "time"

// Update is what the check for a newer release of Nushi found.
type Update struct {
	// The newer release, if there is one: its version ("0.1.17") and its
	// page.
	Version string
	URL     string
	// Latest is the latest release, newer or not; "" until GitHub answered.
	Latest string
	// Checked is when GitHub last answered; zero: not yet.
	Checked time.Time
	// Installing says Homebrew is upgrading Nushi now (ADR 0109);
	// InstallError why the last upgrade failed, in a sentence or two to
	// show; Installed the version the last one brought, "" until one has.
	Installing   bool
	InstallError string
	Installed    string
}
