# AGENTS

## Entry Point
- Treat this file as the top-level Codex workflow and navigation file.
- Read this file before planning or editing the codebase.

## Source Of Truth
- Treat `.codex/` as the primary source for project markdown guidance.
- Before making plans or edits, review relevant `.md` files inside `.codex/`.
- If root-level docs conflict with `.codex` docs, follow `.codex`.

## Working Rule
- Prefer existing instructions in `.codex` over creating new conventions.
- Keep changes aligned with documented architecture, style, and workflows found there.
- Read `.codex/MEMORIES.md` before planning or implementation work.
- Read `.codex/documents/ONBOARDING.md` to select the relevant architecture and style docs for the task.

## Command Templates
- `.codex/commands/` contains repo-local prompt templates, not automatic slash commands.
- When the user asks to run a template from `.codex/commands/`, read that file and follow it.
- Prefer Codex skills for reusable workflows when a matching skill exists.

## Codex Skills
- Reusable migrated workflows live under `.codex/skills/`.
- Current planned migrated skills:
  - `roblox-plan`
  - `roblox-implement-feature`
  - `roblox-review`
  - `roblox-refactor-better`
  - `roblox-suggest-result`
  - `roblox-documentation`
