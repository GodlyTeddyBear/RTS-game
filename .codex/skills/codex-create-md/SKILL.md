---
name: codex-create-md
description: Use when the user asks to create a new markdown document in .codex/, including method contracts, architecture docs, onboarding entries, or skill/command files.
---

# Codex Create MD

- Use this skill to author a new `.codex/` markdown file that follows this project's formatting and content standards.

---

## Workflow

1. Read `AGENTS.md`.
2. Read `.codex/MEMORIES.md` and `.codex/documents/ONBOARDING.md`.
3. If `$ARGUMENTS` names a topic or path, use it. If empty, ask the user what type of MD (method contract, architecture doc, skill, command) and where it should live.
4. Read 2-3 existing MDs in the same category to internalize the format already in use.
5. If creating a method contract, read `.codex/documents/methods/METHODS_INDEX.md`.
6. Follow the full authoring contract in `references/create-md.md`.
7. Write the new file.
8. Update any relevant index file (`METHODS_INDEX.md`, `ONBOARDING.md`) to link to the new file.

---

## Requirements

- Produce a file that passes every item in the pre-save checklist defined in `references/create-md.md`.
- Do not leave stubs. The file must be complete and immediately usable by an agent.
