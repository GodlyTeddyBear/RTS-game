# Onboarding

A map of this project's knowledge base. Read this first to know where to look.

---

## What kind of task are you doing?

### "I need to understand the backend architecture"
→ Start with [architecture/backend/BACKEND.md](architecture/backend/BACKEND.md)
→ Then [architecture/backend/DDD.md](architecture/backend/DDD.md) for layer rules and constructor injection
→ Then [architecture/backend/ERROR_HANDLING.md](architecture/backend/ERROR_HANDLING.md) for the success/error pattern

### "I need to understand the frontend architecture"
→ Start with [architecture/frontend/FRONTEND.md](architecture/frontend/FRONTEND.md)
→ Then [architecture/frontend/HOOKS.md](architecture/frontend/HOOKS.md) for read/write hook separation
→ Then [architecture/frontend/DESIGN.md](architecture/frontend/DESIGN.md) for visual style, cards/panels, hierarchy, and interaction states
→ Then [architecture/frontend/UDIM_LAYOUT_RULES.md](architecture/frontend/UDIM_LAYOUT_RULES.md) for scale-vs-offset UI layout rules
→ Then [architecture/frontend/DEPENDENCY_RULES.md](architecture/frontend/DEPENDENCY_RULES.md) for what can import what

### "I'm adding a new feature to the backend"
→ Use the `roblox-implement-feature` skill with the `new-context` reference to scaffold a full bounded context
→ Use the `roblox-implement-feature` skill with the `new-service` reference to add a single service inside an existing context
→ Reference [architecture/backend/DDD.md](architecture/backend/DDD.md) for which layer the service belongs to

### "I want Codex to implement a feature end-to-end"
→ Use the `roblox-implement-feature` skill
→ It requires pre-reading relevant architecture docs and context files before edits
→ Use the `roblox-plan` skill first if you want a plan before implementation

### "I'm adding a new frontend feature"
→ Use the `roblox-implement-feature` skill with the `new-feature` reference to scaffold a full feature slice
→ Reference [architecture/frontend/LAYERS.md](architecture/frontend/LAYERS.md) for layer responsibilities

### "I'm reviewing or fixing code"
→ Use the `roblox-review` skill for a structured review against all architecture rules
→ Use `/reconcile-context <ContextName> [--apply]` to audit a full backend context for completeness (layers, wiring, persistence lifecycle, sync placement)
→ Use `/improve-ui <path>` to analyze a UI screen/component and get separation-focused refactor suggestions
→ Use `/lint <path>` to run Selene and surface linter errors
→ Or invoke the `context-reviewer` agent for a deep per-context DDD review

### "I need to restore entity state when a player rejoins"
→ Read [architecture/backend/CQRS.md](architecture/backend/CQRS.md) — "Restore Commands" section for the two-pass pattern
→ Read [architecture/backend/POLICIES_AND_SPECS.md](architecture/backend/POLICIES_AND_SPECS.md) — "Policies in Restore Commands" for why policies must not be skipped
→ Key rules: entities are created in pass 1, `SyncDirtyEntities` flushes models, restore commands run in pass 2 after models exist; `LotSpawned` must fire after the lot's own sync flush

### "Something isn't syncing to clients"
→ Read [architecture/backend/STATE_SYNC.md](architecture/backend/STATE_SYNC.md)
→ Check: getters must deep clone; mutations must go through sync service; nested tables need targeted cloning

### "I need to wire context load/save with persistence"
→ Read [architecture/backend/SYSTEMS.md](architecture/backend/SYSTEMS.md) for ProfileStore + persistence event flow
→ Read `src/ReplicatedStorage/Events/GameEvents/Misc/Persistence.lua` for canonical event names
→ Read `src/ServerScriptService/Persistence/PlayerLifecycleManager.lua` for loader readiness contract (`RegisterLoader` / `NotifyLoaded`)

### "I need to understand coding conventions"
→ [coding-style/CODING_STYLE.md](coding-style/CODING_STYLE.md) — naming, type annotations, file structure
→ [coding-style/IMMUTABILITY.md](coding-style/IMMUTABILITY.md) — what to freeze and when
→ [coding-style/READABILITY.md](coding-style/READABILITY.md) — composed methods, abstraction levels, stepdown rule
→ [coding-style/LUAU_TYPES.md](coding-style/LUAU_TYPES.md) — Luau type system patterns and common solver issues
→ [coding-style/MOONWAVE.md](coding-style/MOONWAVE.md) — doc comment syntax for public APIs and hover docs

### "I need to understand a design pattern used in this project"
→ [patterns/NEGATIVE_SPACE.md](patterns/NEGATIVE_SPACE.md) — explicit failure handling by layer
→ [patterns/DEBUG_LOGGING.md](patterns/DEBUG_LOGGING.md) — DebugLogger usage and milestones

---

## Full Document Index

### Architecture
| File | Purpose |
|------|---------|
| [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) | Root index linking backend and frontend |
| [architecture/UNLOCK_REGISTRY.md](architecture/UNLOCK_REGISTRY.md) | Context-owned unlock definitions merged into UnlockConfig |
| [architecture/backend/BACKEND.md](architecture/backend/BACKEND.md) | Backend overview and quick rules |
| [architecture/backend/DDD.md](architecture/backend/DDD.md) | Three-layer DDD, constructor injection, value objects |
| [architecture/backend/CQRS.md](architecture/backend/CQRS.md) | Command/Query separation, restore commands, dependency rules |
| [architecture/backend/KNIT.md](architecture/backend/KNIT.md) | Knit framework, auto-discovery, lifecycle |
| [architecture/backend/ERROR_HANDLING.md](architecture/backend/ERROR_HANDLING.md) | Success/data pattern, logging rule, assertions |
| [architecture/backend/POLICIES_AND_SPECS.md](architecture/backend/POLICIES_AND_SPECS.md) | Specifications, Policies, eligibility checking, candidate types |
| [architecture/backend/STATE_SYNC.md](architecture/backend/STATE_SYNC.md) | Deep clone, targeted cloning, centralized mutation |
| [architecture/backend/SYSTEMS.md](architecture/backend/SYSTEMS.md) | JECS, ProfileStore, debug config, libraries |
| [architecture/frontend/FRONTEND.md](architecture/frontend/FRONTEND.md) | Frontend overview and feature slice structure |
| [architecture/frontend/LAYERS.md](architecture/frontend/LAYERS.md) | Infrastructure, Application, Presentation layers |
| [architecture/frontend/COMPONENTS.md](architecture/frontend/COMPONENTS.md) | Atomic Design hierarchy and extraction rules |
| [architecture/frontend/HOOKS.md](architecture/frontend/HOOKS.md) | Read/write hook separation, ViewModels, Selectors |
| [architecture/frontend/DESIGN.md](architecture/frontend/DESIGN.md) | Visual style creation, cards/panels, hierarchy, chrome, and interaction states |
| [architecture/frontend/UDIM_LAYOUT_RULES.md](architecture/frontend/UDIM_LAYOUT_RULES.md) | Scale-first layout rules and offset-only decorative exceptions |
| [architecture/frontend/DEPENDENCY_RULES.md](architecture/frontend/DEPENDENCY_RULES.md) | Allowed and prohibited import directions |
| [architecture/frontend/ANTI_PATTERNS.md](architecture/frontend/ANTI_PATTERNS.md) | Common mistakes and correct alternatives |

### Coding Style
| File | Purpose |
|------|---------|
| [coding-style/CODING_STYLE.md](coding-style/CODING_STYLE.md) | PascalCase, camelCase, SCREAMING_SNAKE_CASE, --!strict |
| [coding-style/IMMUTABILITY.md](coding-style/IMMUTABILITY.md) | table.freeze rules — configs, result objects, value objects |
| [coding-style/READABILITY.md](coding-style/READABILITY.md) | Composed methods, abstraction levels, stepdown rule, tell-don't-ask |
| [coding-style/LUAU_TYPES.md](coding-style/LUAU_TYPES.md) | Luau type system patterns, generic chaining, recursive types |
| [coding-style/MOONWAVE.md](coding-style/MOONWAVE.md) | Moonwave doc comment syntax, luau-lsp hover docs |

### Patterns
| File | Purpose |
|------|---------|
| [patterns/NEGATIVE_SPACE.md](patterns/NEGATIVE_SPACE.md) | Failure handling per layer (assert → pcall → validate → pass-through) |
| [patterns/DEBUG_LOGGING.md](patterns/DEBUG_LOGGING.md) | DebugLogger setup and milestone logging |
| [patterns/PROGRAMMING_PATTERNS.md](patterns/PROGRAMMING_PATTERNS.md) | GoF design patterns — applicability, Lua idioms, codebase examples |

### Agent Rules
| File | Purpose |
|------|---------|
| [AGENT_RULES.md](AGENT_RULES.md) | Behavioral rules for Codex when working in this project |

---

## Available Codex Skills

| Skill | What it does |
|---------|-------------|
| `roblox-plan` | Generate a strict, execution-ready Roblox implementation plan using a structured output schema (no code). |
| `roblox-implement-feature` | Implement a feature end-to-end and handle new-context, new-service, or new-feature scaffolding when needed. |
| `roblox-review` | Review code against DDD, error handling, state sync, and style rules. |
| `roblox-refactor-better` | Analyze or refactor code for readability, abstraction quality, naming, control flow, and project fit. |
| `roblox-suggest-result` | Suggest or apply the backend Result/error-handling pattern and boundary rules. |
| `roblox-documentation` | Update project docs or inline comments using Moonwave and readability rules. |

## Repo-Local Templates

| Template area | What it does |
|-------|-------------|
| `.codex/commands/` | Prompt template archive. Codex does not automatically expose these as slash commands. Prefer matching skills when available. |
| `.codex/agents/` | Legacy agent prompt archive kept for migration reference. |