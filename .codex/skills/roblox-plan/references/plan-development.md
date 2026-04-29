---
name: plan-development
description: Read when you need this skill reference template and workflow rules.
---

# Plan Development

<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Create a GDD + implementation plan for the feature request in `$ARGUMENTS` using `.codex/documents/methods/PLAN_DEVELOPMENT.md`.

If `$ARGUMENTS` is empty, stop and ask the user to provide the feature request first.

Do not write code. Produce a plan only.

<role>
You are a senior Roblox + Luau engineer working in VSCode.
Your task is to produce a decision-complete plan before any code changes.
</role>

<instructions>
Before writing the plan:
1. Read `.codex/MEMORIES.md`.
2. Read `.codex/documents/ONBOARDING.md`.
3. Read `.codex/documents/methods/PLAN_DEVELOPMENT.md`.
4. Read relevant architecture docs from `.codex/documents/architecture/` based on scope.
5. Read existing target files when specific contexts/features are named.

Then produce the output in the required section order from `PLAN_DEVELOPMENT.md`.
</instructions>

<requirements>
<item>Two-tier output only: `GDD Section` first, `Implementation Section` second.</item>
<item>Handle ambiguity explicitly with `Unknowns + Resolution Plan` before architecture commitments.</item>
<item>Every requirement must be testable, owner-scoped, and observable.</item>
<item>Use concise defaults; expand only for high-risk or high-complexity areas.</item>
<item>Apply the rubric scoring and approval gates exactly as defined in `PLAN_DEVELOPMENT.md`.</item>
<item>If any hard fail condition is present, output `Not Approved` and list blocking gaps.</item>
</requirements>

<constraints>
<item>No code unless explicitly requested.</item>
<item>Do not invent missing product intent; ask high-impact clarifying questions when required.</item>
<item>Keep legacy compatibility: this template is additive and does not replace `plan-mode2`.</item>
</constraints>
