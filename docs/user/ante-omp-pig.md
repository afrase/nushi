# Ante, oh-my-pi and PiG

What to install and configure for the agents Nushi runs without setting them up.

## Ante, oh-my-pi and PiG for you

- **Ante**: nothing to install. The bridge is inside `nushid`; it runs the `ante` on `PATH`, else `~/.ante/bin/ante` (yours is 0.2.14, the version it follows; 0.2.15, out on 2026-10-23, changed nothing in the protocol per its notes, so `ante update` should be fine). It uses your `~/.ante` as Ante does: your default model (Kimi K3 on Fireworks) until you pick another in the chat. `FIREWORKS_API_KEY` reaches it from fish, as it reaches Codex.
- **oh-my-pi**: install Bun and omp yourself (below); Settings › Agents then shows it. omp reads `FIREWORKS_API_KEY` from the environment and lists Fireworks' models; it starts on Kimi K3 at max effort. To start on DeepSeek, put this in `~/.omp/agent/config.yml` (I didn't write it):

```yaml
modelRoles:
  default: fireworks/deepseek-v4.1-flash
```

  Nushi runs your `omp` (since milestone Z it brings none): `brew install oven-sh/bun/bun` (or `npm i -g bun`) and `bun add -g @oh-my-pi/pi-coding-agent@18.12.6` (the version Nushi was tried with; `~/.bun/bin` must be on your login shell's PATH).

- **PiG**: install `pig` (`curl -fsSL https://pi-in-go.dev/install.sh | sh`, or `npm i -g @pi-in-go/pig`; Nushi was tried with 0.5.3) so it's on your login shell's `PATH`; Settings › Agents then says Ready. It uses your `~/.pig` as PiG does and reads `FIREWORKS_API_KEY` from the environment. To start new chats on DeepSeek, put this in `~/.pig/agent/settings.json` (I didn't write it):

```json
{ "defaultProvider": "fireworks", "defaultModel": "accounts/fireworks/models/deepseek-v4p1-flash", "defaultThinkingLevel": "low" }
```

  PiG never asks before a tool call. A repository's `.pig` settings and extensions load in Nushi only after you trust the folder in a terminal `pig` (`/trust`).
