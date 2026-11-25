package chats

import "fmt"

// chatOp is what a chat is busy with: a turn, or one of the steps on its
// session (a reopen, a reload, an open, a start, a fork, a move or a
// rewind). They exclude each other: each begins only on a chat busy with
// none (busyLocked), but a Move whose session must be replayed hands its
// own to the reopen that does it. The teardown flags (stopping, halting,
// held, retiring) are another axis, and stay apart.
type chatOp uint8

const (
	opNone   chatOp = iota
	opTurn          // a prompt's turn (startLocked)
	opReopen        // session/load on a chat whose agent isn't running (reopenLocked)
	opReload        // the same on a new agent, asked for (Reload)
	opOpen          // a session of the agent's opened as a chat (Open)
	opStart         // a new chat put on its picks (Start)
	opFork          // a fork put on the chat's picks (ForkAsChat)
	opMove          // Move, until the chat runs in its new folder
	opRewind        // Rewind, until the fork is on the chat's picks
)

// busyLocked says the chat is busy with an op: a message waits, and what
// needs the chat quiet waits or is refused. It is Status.Busy.
func (c *chat) busyLocked() bool { return c.op != opNone }

// beginOpLocked marks the chat busy with o. A reopen and a reload make
// woke, which awake waits on until they end; the caller says the status
// once the rest of its step is set.
func (c *chat) beginOpLocked(o chatOp) {
	c.op = o
	if o == opReopen || o == opReload {
		c.woke = make(chan struct{})
	}
}

// endOpLocked ends the chat's op: woke is closed, and the chat says its
// status and hands the queue its chance. A turn's end does neither here:
// it says its status with how it ended (turnEndedLocked), and delivers
// once its notices are in (run).
func (c *chat) endOpLocked() {
	was := c.op
	c.op = opNone
	if c.woke != nil {
		close(c.woke)
		c.woke = nil
	}
	if was == opTurn {
		return
	}
	c.statusChangedLocked()
	c.deliverLocked()
}

// doing is what a chat busy with o is doing, as its refusals say it.
func (o chatOp) doing() string {
	switch o {
	case opNone:
		return "idle"
	case opTurn:
		return "working on a turn"
	case opReopen:
		return "reopening"
	case opReload:
		return "reloading"
	case opOpen:
		return "opening"
	case opStart, opFork: // a new chat put on its picks
		return "starting"
	case opMove:
		return "moving"
	case opRewind:
		return "rewinding"
	}
	return "busy"
}

// stillLocked says what the busy chat is still doing, for a refusal: the
// agent's turn, or the step on its session by name.
func (c *chat) stillLocked() string {
	if c.op == opTurn {
		return "the agent is still working on the last prompt"
	}
	return "the chat is still " + c.op.doing()
}

// sessionOpErrLocked refuses what must wait for the chat's step on its
// session (sessionOpLocked) to end, naming it.
func (c *chat) sessionOpErrLocked() error {
	return fmt.Errorf("%s; try again in a moment", c.stillLocked())
}
