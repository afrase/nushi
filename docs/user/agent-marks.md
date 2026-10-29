# Agent marks

Where each agent's mark comes from, and its terms.

## Agent marks (2026-10-25)

One mark per agent wherever a chat's agent shows (`app/lib/agent_mark.dart`), drawn in one color from paths bundled in the source; nothing is fetched. An agent without one gets its initial on a rounded square.

| Agent | Source | Terms |
|---|---|---|
| Claude | the ACP registry's `claude-acp.svg` (`cdn.agentclientprotocol.com/registry/v1/latest/`; the registry repository is Apache-2.0, its Claude entry says "proprietary"), numbers rounded to 0.1 of its 1200 box | The Claude mark is Anthropic's trademark. Anthropic's trademark guidelines (anthropic.com/legal/trademark-guidelines) allow use only as Anthropic permits, with no change of color, font or proportion, and nothing that implies endorsement. The registry itself serves it in one color (`currentColor`) for ACP clients to show. |
| Codex | the registry's `codex-acp.svg` (codex-acp is Apache-2.0) | The OpenAI Blossom, OpenAI's trademark, under OpenAI's brand guidelines (openai.com/brand; the page answered 403, so not read). |
| Ante | `docs-site/static/assets/ante.png` in AntigmaLabs/ante (its docs' logo), redrawn as its rows of pixels | The repository is Apache-2.0, which grants no trademark rights (§6). |
| oh-my-pi | `assets/icon.svg` in can1357/oh-my-pi (MIT): the π with a plug, its two decorative dots left out (they'd vanish in one color) | MIT for the file; the mark is the project's. |
| PiG | the pig head its terminal draws (`pigMascot`, a 16×14 sprite in `coding/piglogin/art.go` of MichaelKinsy/PiG), in one color with the eyes and snout cut out | MIT (the repository's `REUSE.toml` puts `coding/**` under MIT, Michael Kinsy and Mario Zechner); no brand policy found. The project banner (`docs/assets`) is MIT and CC-BY-4.0 (it holds the Go gopher) and isn't used. |

Each mark only names the agent beside a chat (nominative use); none stands for Nushi. That's fine for a personal app; before Nushi is published, ask Anthropic and OpenAI, or drop their entries from `_marks` (each then shows its monogram).
