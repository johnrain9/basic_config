---
name: shared-memory
description: Use when the user refers to prior preferences, recurring workspace conventions, or cross-provider memory, especially when context established in Claude should also be available to Codex or vice versa.
---

# Shared Memory

Use the tracked shared-memory files as the portable memory layer across providers.

## Read Order

When the task depends on durable user or workspace context, read the canonical files in:

- `~/projects/basic_config/ai/memories/*.md`

If the repo is unavailable, fall back to the synced provider-local mirrors:

- Codex: `~/.codex/memories/shared/*.md`
- Claude: `~/.claude/memories/shared/*.md`

## When To Use It

- The user says a preference or convention was already explained before
- The user asks for provider-agnostic behavior
- You need stable workspace conventions such as repo layout or bootstrap ownership
- You are deciding whether a new preference belongs in durable memory

## What Belongs In Shared Memory

- Stable user workflow preferences
- Durable workspace conventions
- Cross-provider operating rules
- Repo-level facts that are likely to matter again

## What Does Not Belong Here

- Secrets or tokens
- One-off task state
- Ephemeral debugging notes
- Long transcripts or raw review output

## Update Discipline

When a new durable fact should be shared across providers:

1. Update or add a concise note under `~/projects/basic_config/ai/memories/`.
2. Sync it with `~/projects/basic_config/setup.sh sync-ai`.
3. Keep entries short, factual, and stable.

Prefer editing an existing note over creating many tiny files.
