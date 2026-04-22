---
name: codex-improve-md
description: Use when the user asks to improve, audit, or rewrite an existing markdown file in .codex/ by applying formatting rules, tightening constraints, removing redundancy, and adding missing sections.
---

# Codex Improve MD

- Use this skill to audit and rewrite an existing `.codex/` markdown file so it meets this project's formatting and content standards.

---

## Workflow

1. Read `AGENTS.md`.
2. Read `.codex/MEMORIES.md` and `.codex/documents/ONBOARDING.md`.
3. Read the target file at `$ARGUMENTS` in full. If empty, ask the user which file to improve.
4. Identify the file type (method contract, architecture doc, skill, command) from its location and structure.
5. Read 1-2 sibling files of the same type to calibrate the expected format.
6. Follow the full audit and rewrite contract in `references/improve-md.md`.
7. Rewrite the file in place.
8. Print a one-line summary of what changed (sections added, restructured, or removed).

---

## Requirements

- Do not change the intent or meaning of any existing rule.
- Rewrite only structure, formatting, and completeness.
- Ensure the rewritten file passes every audit checklist item in `references/improve-md.md`.
