# 0060. A chat keeps its picks

## Context
"Does the model selection get remembered? Mine's stuck on a specific model even after changing." Only the mode was kept. Claude reopens a session (`session/load`) on its default model and effort, and a chat reopens after every sleep, daemon restart (one each update) and reload; sleep put the options back from memory, so a restart dropped them silently.

## Decision
- A chat keeps its picks (`Session.Picks`): each option the user changed other than the mode and Ultracode (model, effort, fast, ...), by option ID. A new session's defaults aren't picks.
- A pick follows what the agent then says that option is on (its own `/model`, as Ante's bridge has; a fallback it makes for the session), but not while a session is being opened and put back.
- Every open of the chat's session (load after sleep, restart or reload; a rewind's or a move's fork) sets each pick the agent still offers, before a prompt can run: the model first (the effort's values depend on it), then the rest in the agent's order, then the mode. A value already current isn't set again (Ante, PiG and omp keep the model in their sessions). One the agent no longer offers (a retired model) is dropped from the chat and logged.
- Each agent remembers its last picks beside its mode (`agents.json`): a new chat starts on those it offers, else on its defaults. A session opened from elsewhere gets only the mode: Ante, PiG and omp keep the model it was on.

## Consequences
- Side chats get nothing set: they have no options of their own (until 2026-11-05: see the amendment).
- Chats from before this ADR have no picks: they come back on the agent's defaults once, until something is picked.

## Amendment (2026-11-05): side chats start on their chat's
"A side chat doesn't inherit the permissions of the parent and there isn't a way to change it." The fork ran on whatever mode and options the agent gives a fork (its defaults), from a chat in Manual or Plan too, and the side chat had no options to show: the fork's answer was dropped.
- A side chat starts on its chat's mode (what the agent says the chat is on) and picks, put on its session as on any open of a chat's (`Fork`, `reapply`). What the agent then reports is what it shows: one it refuses leaves the side chat on the agent's.
- Its composer has the chat's mode and option pickers (not Ultracode, its agent's process's, its chat's). A change sets its session only: not its chat's, and not its agent's remembered mode or picks (`agents.json`), since an aside isn't what the user picks to work in. Keep as chat keeps what it is on.

## Alternatives considered
- Restoring the whole set of options from before (what sleep did): it kept agent defaults as if picked, and lived only in memory.
