# Review Workflows

- Prefer cross-provider review bundles over single-provider review when design or architecture quality matters.
- For product and UI design docs, use the `design-ui` bundle:
  - `visual_design_critique` -> Codex / GPT-5.4 high
  - `ux_product_critique` -> Codex / GPT-5.4 high
  - `implementation_system_reality` -> Opus high
- For frontend system-design HLDs, prefer Opus high as the primary author and review with the `frontend-hld` bundle.
- For frontend LLDs, use the `frontend-lld` bundle and include higher-level context such as the parent HLD, prior review summary, and adjacent LLDs when contracts overlap.
- After a moderate revision, prefer rereview against prior findings instead of a fully fresh review. Use a fresh review again only when the document changed substantially.
