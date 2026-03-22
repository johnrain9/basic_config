# Workspace Conventions

- `~/projects` is the default workspace root. Use `$PROJECTS_DIR` or repo-root-relative resolution instead of hardcoded user paths.
- `basic_config` is the machine-bootstrap source of truth for shared shell setup and provider-agnostic AI parity wiring.
- `CENTRAL` lives under `~/projects/CENTRAL` in the standard layout and is the canonical home for multi-repo planning, dispatch, and the document review tool.
- Prefer portable paths and env-overridable repo resolution in scripts and docs.
