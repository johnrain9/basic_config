# Memory Management

- When a new memory should persist across providers, add it to the tracked shared-memory source under `~/projects/basic_config/ai/memories/` first.
- After updating shared memory, run `~/projects/basic_config/setup.sh sync-ai` so Codex and Claude both receive the same durable context.
- Do not rely on only one provider's private memory surface for durable workflow preferences or workspace conventions when the information should be shared.
