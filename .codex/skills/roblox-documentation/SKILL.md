---
name: roblox-documentation
description: Use when the user asks Codex to update project documentation, add or revise inline comments, apply Moonwave documentation rules, or improve docs/comments in this Roblox + Luau repo.
---

# Roblox Documentation

- Use this skill for documentation, module-overview, section-comment, and inline-comment work in this repo.

---

## Workflow

1. Read `AGENTS.md`.
2. Read `.codex/MEMORIES.md` and `.codex/documents/ONBOARDING.md`.
3. For public API docs or Moonwave annotations, read `.codex/documents/coding-style/MOONWAVE.md`.
4. For inline comments or readability-driven docs, read `.codex/documents/coding-style/READABILITY.md`.
5. Run all three references in this order for documentation tasks:
   - `references/add-overview.md` (top-of-file module overviews and section headers).
   - `references/update-documentation.md` (Moonwave/public API docs).
   - `references/add-inlines.md` (inline intent/phase comments).

---

## Requirements

- Do not invent documentation style.
- Keep comments sparse, useful, and aligned with the repo's existing conventions.
- For overview work, place the Moonwave `@class` overview immediately under the file's `--!` pragma.
- For overview work, use the scheduler-style `--[=[ ... ]=]` block and indent overview lines by 4 spaces.
- For section-comment work, use scheduler-style separator headers such as `-- ── Private ──────────────────────────────────────────────────────────────────`.
