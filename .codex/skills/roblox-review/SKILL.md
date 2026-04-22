---
name: roblox-review
description: Use when the user asks for a Roblox code review, architecture review, DDD/CQRS review, frontend layer review, or wants findings against this repo's Codex guidance and style rules.
---

# Roblox Review

- Use this skill for code reviews in this Roblox + Luau repo.

---

## Workflow

1. Read `AGENTS.md`.
2. Read `.codex/MEMORIES.md` and `.codex/documents/ONBOARDING.md`.
3. Read the relevant architecture and style docs for the target area.
4. Read target files before making claims.
5. Produce findings first, ordered by severity, with file and line references.
6. Follow the review output contract in `references/review.md`.

---

## Review Focus

- Prioritize bugs, behavioral regressions, architecture boundary violations, unsafe state sync, error-handling violations, frontend dependency violations, and missing targeted validation.
