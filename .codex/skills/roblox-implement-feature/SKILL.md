---
name: roblox-implement-feature
description: Use when the user asks Codex to implement a Roblox feature end-to-end, scaffold a new backend context, add a backend service, or create a frontend feature slice using this repo's DDD, CQRS, Knit, frontend feature-slice, Result/error, persistence, and validation rules.
---

# Roblox Implement Feature

Use this skill to implement a complete Roblox + Luau feature slice in this repo, including related scaffolding when the request needs a new context, service, or frontend feature.

## Workflow

1. Read the repo root `AGENTS.md`.
2. Read `.codex/MEMORIES.md` and `.codex/documents/ONBOARDING.md`.
3. Determine backend, frontend, or mixed scope.
4. Read the required architecture docs and target code before editing.
5. If scaffolding is required, read the matching reference:
   - `references/new-context.md` for a backend bounded context.
   - `references/new-service.md` for an Application, Domain, or Infrastructure service.
   - `references/new-feature.md` for a frontend feature slice.
6. Implement working code, wiring, and validation checks; do not leave partial stubs.
7. Run targeted lint/build checks when available.
8. Follow the completion checklist and response format in `references/implement-feature.md`.

## Requirements

Preserve DDD/CQRS boundaries, Result/WrapContext rules, centralized errors and types, frontend layer boundaries, read/write hook separation, and persistence lifecycle contracts when touched.
