# Operator Preferences

- Prefer provider-agnostic setup for AI tooling. Different providers can use different models and flags, but durable context should not live in only one provider.
- Shared skills and shared memory should be tracked in repos, then synced into provider homes, instead of relying only on opaque provider-local state.
- Avoid making the user repeat stable preferences or workflow context to Codex if it was already established for Claude, and vice versa.
- Use high-effort settings for serious design and architecture review work unless there is a clear reason not to.
