<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Add or update top-of-file module overview blocks and major section comments for the file or folder specified in `$ARGUMENTS`. Write changes directly into each target file, not as a report.

If `$ARGUMENTS` is empty, stop and ask the user for a file or folder path first.

---

## Before starting

Read the following docs before writing any overview block:

- `.codex/MEMORIES.md`
- `.codex/documents/ONBOARDING.md`
- `.codex/documents/methods/backend/APPLICATION_CONTRACTS.md` (for backend application modules)
- `.codex/documents/methods/backend/CONTEXT_BOUNDARIES.md` (for ownership and cross-context boundaries)

Do not write overviews without reading relevant architecture/method docs for the files you touch.

---

## How to run

1. Read every target `.lua` file in `$ARGUMENTS`.
2. Detect whether a top-of-file overview already exists.
3. If one exists, rewrite it to match the contract below; if missing, add one at the top of the file.
4. Add or normalize major section comments using the section contract below.
5. Keep existing Moonwave/doc comments and function comments intact. Only add or update the overview block and section headers.
6. Keep each overview concise and stable. Avoid implementation-level details.
7. After edits, output the summary using the required output format.

---

## Overview Contract

Every module overview must use a top-of-file Moonwave class block:

```lua
--[=[
    @class ServerScheduler
    Singleton Planck scheduler that owns and drives all server-side ECS systems.

    Contexts register their systems during `KnitStart()` via `RegisterSystem()`.
    `Runtime.server.lua` calls `Initialize()` after `Knit.Start()` resolves, which
    builds the pipeline, flushes queued systems, and connects to `RunService.Heartbeat`.
    @server
]=]
```

Required content:

1. `@class <Name>` using the file/module name.
2. A concise ownership statement that explains what the module owns.
3. System context only when it clarifies where or when the module is invoked.
4. `@server`, `@client`, or both depending on where the module runs.

Optional content:

- A short high-level flow or ordered phase list when the module is an orchestrator.
- Boundary wording when ownership could be confused with another layer or context.

### Style rules

- Use Moonwave block comment style: `--[=[ ... ]=]`.
- Place the overview immediately below the `--!` pragma (`--!strict` or equivalent) when present.
- If no `--!` pragma exists, place the overview at absolute top-of-file.
- Indent each overview content line by 4 spaces inside the block.
- Keep most overviews concise; allow longer blocks for schedulers, orchestration modules, or phase lists.
- Prefer contract language (owns/does not own/must) over narrative.
- Describe intent and system role, not branch-by-branch behavior.
- Use stable wording that will survive refactors.

### High-Level Flow rules

- Include only a high-level flow, never a step-by-step guide.
- Limit to 3-5 phases max, single line, `A -> B -> C` format.
- Flow is for architecture context, not troubleshooting or implementation detail.

## Section Comments Contract

Use scheduler-style separator headers for major file divisions:

```lua
-- ── Private ──────────────────────────────────────────────────────────────────
```

Allowed labels:

- `Types`
- `Constants`
- `Public`
- `Private`
- `Initialization`
- Context-specific labels only when they improve scanning more than a generic label.

### Section style rules

- Use the exact separator style: `-- ── <Label> ──────────────────────────────────────────────────────────────────`.
- Apply only to major divisions, not every function.
- Keep section names short and consistent across files.
- Use vertical whitespace between sections.

### Small example

```lua
--!strict

--[=[
    @class UseAbilityCommand
    Executes the application use-case for commander ability activation.

    Called by `CommanderContext` from validated player input handling.
    Flow: Parse request -> enforce policy/spec -> invoke runtime service -> return Result.
    Owns orchestration only; does not own cooldown math, targeting formulas, or transport wiring.
    @server
]=]

local AbilityPolicy = require(script.Parent.Parent.Parent.CommanderDomain.Policies.AbilityPolicy)

-- ── Public ───────────────────────────────────────────────────────────────────

local function Execute(dependencies, input)
    return dependencies.AbilityRuntimeService:UseAbility(input)
end

-- ── Private ──────────────────────────────────────────────────────────────────

local function _normalizeInput(input)
    return input
end
```

---

## Prohibitions

- Do not add procedural tutorials or long usage guides in the overview.
- Do not duplicate full method docs, policy docs, or design docs.
- Do not claim ownership for behavior handled by other layers/contexts.
- Do not remove existing file headers that contain valid project-specific docs.
- Do not use ASCII-only separators like `-----` or `==========`.
- Do not use bracket headers like `-- [Private Helpers]` for new overview work.

---

## Output format

After editing, output:

```text
Files updated: N
```

Then for each updated file:

```text
## [file path]
- Added overview: yes|no
- Updated overview: yes|no
- Included High-Level Flow: yes|no
- Updated section comments: yes|no
```
