<!-- Skill reference for the default GDD + implementation planning format. -->

Use `.codex/commands/plan-development.md` as the canonical prompt template.

Core expectations:
- Output `GDD Section` before `Implementation Section`.
- Follow the stable output contract in `.codex/documents/methods/PLAN_DEVELOPMENT.md`.
- Apply rubric scoring and approval gates; fail with explicit blocking gaps when required.
- Keep output concise by default, expanding only for high-risk/high-complexity areas.
- Keep `plan-mode2` available for explicit legacy requests.
