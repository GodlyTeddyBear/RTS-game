---
name: roblox-plan
description: Use when the user wants a strict, execution-ready Roblox and Luau implementation plan for a feature request, especially when they ask for a Claude-like plan, plan-mode2 behavior, architecture-aware planning, or no-code planning before implementation.
---

# Roblox Plan

- Use this skill to produce detailed Roblox + Luau plans without editing code.

---

## Workflow

1. Read the repo root `AGENTS.md`.
2. Read `.codex/MEMORIES.md` and `.codex/documents/ONBOARDING.md`.
3. Select relevant architecture docs from `.codex/documents/` based on the feature scope.
4. Read existing target files if the plan concerns a known context, feature, or module.
5. Produce a plan only. Do not write code.
6. Default to the GDD + implementation format in `references/plan-development.md`.
7. If the user explicitly asks for legacy `plan-mode2` format, use `references/plan-mode2.md`.

---

## Output Requirements

- The plan must be implementation-ready.
- The plan must identify assumptions and ambiguities.
- The plan must describe client/server boundaries, data flow, networking contracts, validation, risks, and testing.
- The plan must include rubric scoring and explicit approval status.
