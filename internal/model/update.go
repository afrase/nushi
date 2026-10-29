package model

import "time"

// Update is what the check for a newer release of Nushi found.
type Update struct {
	// The newer release, if there is one: its version ("0.1.17"), its page
	// and when it was published.
	Version   string
	URL       string
	Published time.Time
	// Latest is the latest release, newer or not; "" until GitHub answered.
	Latest string
	// Checked is when GitHub last answered; zero: not yet.
	Checked time.Time
}
