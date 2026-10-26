# Codex config

A Codex setup for Fireworks, for the owner to put in place.

## Codex config for you

Put these in `~/.codex/` (I didn't write them). `config.toml`:

```toml
model = "accounts/fireworks/models/deepseek-v4p1-flash"
model_provider = "fireworks"
model_catalog_json = "models.json"   # next to this file

[model_providers.fireworks]
name = "Fireworks"
base_url = "https://api.fireworks.ai/inference/v1"
env_key = "FIREWORKS_API_KEY"
wire_api = "responses"
```

Codex has no per-model metadata in `config.toml`: it takes a model catalog (`model_catalog_json`), and each entry needs the system prompt (`base_instructions`) too; without one the catalog fails to load and Codex says "Authentication required". This builds `~/.codex/models.json` from Codex 0.160.1's own prompt (the one its fallback metadata uses), with the model's real window (Fireworks reports 1,048,576 tokens; Codex shows 95% of it, 996k) and three efforts (each tried):

```sh
curl -sL https://raw.githubusercontent.com/openai/codex/rust-v0.160.1/codex-rs/models-manager/prompt.md | jq -Rs '{models: [{
  slug: "accounts/fireworks/models/deepseek-v4p1-flash",
  display_name: "DeepSeek V4.1 Flash",
  description: "DeepSeek V4.1 Flash on Fireworks",
  base_instructions: .,
  default_reasoning_level: "medium",
  supported_reasoning_levels: [
    {effort: "low", description: "Fast responses with lighter reasoning"},
    {effort: "medium", description: "Balances speed and reasoning depth"},
    {effort: "high", description: "Greater reasoning depth for complex problems"}],
  shell_type: "unified_exec", visibility: "list", supported_in_api: true, priority: 1,
  support_verbosity: false, default_verbosity: null, apply_patch_tool_type: null,
  availability_nux: null, upgrade: null,
  truncation_policy: {mode: "bytes", limit: 10000},
  context_window: 1048576, max_context_window: 1048576,
  experimental_supported_tools: [], input_modalities: ["text", "image"]}]}' > ~/.codex/models.json
```

The catalog replaces Codex's own list, so the model picker shows only this model. `FIREWORKS_API_KEY` must be exported by fish's config (it is): agents get the login shell's environment.
