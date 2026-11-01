# 0078. Pi runs on PiG's bridge

## Context
PiG is a Go port of Pi, and its RPC mode is Pi 1.4.0's protocol, so the bridge of [0039](0039-our-own-bridge-for-pig.md) already spoke Pi. Pi 1.4.0, run in a throwaway home against a local fake model, did everything the bridge asks of it: the same commands, events, session files, trust and skill rules ([facts](../facts/pi.md)). What differs is names: the program, its folder and variables, and that Pi runs under Node.

## Decision
- **One bridge.** `internal/pig` is now `internal/pi`, since the protocol is Pi's, and `internal/pigskills` is `internal/piskills`. `pi.Flavor` is plain data (program, version, folder, variable prefix, whether its home can move); `pi.Pi` and `pi.PiG` are its two values. `pi.Harness` and `piskills.Skills` hold a Flavor, so one type serves both, with the same capabilities.
- **Each is its own agent**: `nushid pi-acp` and `nushid pig-acp`, with separate sessions, settings and marks. The bridge answers with the Flavor's name, and `ForkAt` takes only its own.
- **Pi `Needs` Node** and has a `Min`, 0.80.4, the first with `agent_settled`; `get_entries` came one release before. The bridge refuses an older Pi or an unreadable version at initialize, as Ante's does: there's no trust card because Pi gates a folder's code itself (0039), which it does only since 0.79.0, so an older one must not run.
- **The bridge's own wire names became Pi's** (`_pi/context`, `_meta.pi.afterMessage`). The daemon starts its own executable as the bridge, so the two never differ.
- The bridge's errors and logs no longer name the program; "isn't installed" and the skills' messages do, from the Flavor.

## Consequences
- A change to the protocol reaches both, and a difference between them would need a field on Flavor or a branch in the bridge. None exists today; a new Pi may bring one, and the bridge says so in the log when the version isn't the one it follows.
- PiG's users see "the agent has stopped" where the error said "pig has stopped".
- A relative `sessionDir` in Pi's settings resolves from the working folder, not the agent folder as the bridge reads it, so those sessions aren't listed.

## Alternatives considered
- A second package copied from the first: about 2,900 lines to keep the same by hand.
- Keeping the package name `pig`: `pig.Pi` says the port owns the protocol it ports.
