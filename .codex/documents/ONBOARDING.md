# Onboarding

A map of this project's knowledge base. Read this first to know where to look.

---

## What kind of task are you doing?

### "I need to understand the backend architecture"
→ Start with [architecture/backend/BACKEND.md](architecture/backend/BACKEND.md)
→ Then [architecture/backend/DDD.md](architecture/backend/DDD.md) for layer rules and constructor injection
→ Then [architecture/backend/ERROR_HANDLING.md](architecture/backend/ERROR_HANDLING.md) for the success/error pattern

### "I need low-level backend method contracts"
→ Start with [methods/METHODS_INDEX.md](methods/METHODS_INDEX.md)
→ Then [methods/backend/CONTEXT_BOUNDARIES.md](methods/backend/CONTEXT_BOUNDARIES.md) for context boundary ownership and pass-through rules
-> Then [methods/backend/BASE_CONTEXT_CONTRACTS.md](methods/backend/BASE_CONTEXT_CONTRACTS.md) for BaseContext context creation and migration rules
-> Then [methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md](methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md) for registry lifecycle and cross-context dependency wiring
-> Then [methods/backend/ASSET_ACCESS_CONTRACTS.md](methods/backend/ASSET_ACCESS_CONTRACTS.md) for AssetFetcher registry usage and direct asset access prohibitions
→ Then [methods/backend/APPLICATION_CONTRACTS.md](methods/backend/APPLICATION_CONTRACTS.md) for Command/Query execution flow and dependency contracts
→ Then [methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md](methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md) for Policy/Spec contracts and restore-path requirements
→ Then [methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md) for runtime/persistence method boundaries


### "I need to work with ECS entities, systems, or persistence"
→ Start with [methods/ECS/COMPONENT_RULES.md](methods/ECS/COMPONENT_RULES.md) for authority labels and component shape
→ Then [methods/ECS/ENTITY_FACTORY_RULES.md](methods/ECS/ENTITY_FACTORY_RULES.md) for the only JECS mutation surface
→ Then [methods/ECS/SYSTEM_RULES.md](methods/ECS/SYSTEM_RULES.md) for statelessness and read/write ownership
→ Then [methods/ECS/WORLD_ISOLATION_RULES.md](methods/ECS/WORLD_ISOLATION_RULES.md) for per-context world boundaries
→ Then [methods/ECS/PHASE_AND_EXECUTION_RULES.md](methods/ECS/PHASE_AND_EXECUTION_RULES.md) for tick phase order and deferred flushes
→ Then [methods/ECS/TAG_RULES.md](methods/ECS/TAG_RULES.md) for binary state markers vs data components
→ Then [methods/ECS/INSTANCE_REVEAL_RULES.md](methods/ECS/INSTANCE_REVEAL_RULES.md) for replicating instance state to the client
→ Then [methods/ECS/ECS_PERSISTENCE_RULES.md](methods/ECS/ECS_PERSISTENCE_RULES.md) for the ECS↔ProfileStore bridge

### "I need to create or improve planning quality"
→ Start with [methods/PLAN_DEVELOPMENT.md](methods/PLAN_DEVELOPMENT.md)
→ Then use `.codex/commands/plan-development.md` for GDD + implementation planning output
→ Use `roblox-plan` skill; default to the plan-development format, and use `plan-mode2` only for explicit legacy requests
### "I need to understand the frontend architecture"
→ Start with [architecture/frontend/FRONTEND.md](architecture/frontend/FRONTEND.md)
â†’ Then [architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md](architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md) for client context controller/application/infrastructure boundaries
→ Then [architecture/frontend/HOOKS.md](architecture/frontend/HOOKS.md) for read/write hook separation
→ Then [architecture/frontend/DESIGN.md](architecture/frontend/DESIGN.md) for visual style, cards/panels, hierarchy, and interaction states
→ Then [architecture/frontend/UDIM_LAYOUT_RULES.md](architecture/frontend/UDIM_LAYOUT_RULES.md) for scale-vs-offset UI layout rules
→ Then [architecture/frontend/DEPENDENCY_RULES.md](architecture/frontend/DEPENDENCY_RULES.md) for what can import what

### "I need low-level frontend method contracts"
→ Start with [methods/METHODS_INDEX.md](methods/METHODS_INDEX.md)
â†’ Then [methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md](methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md) for controller/application/infrastructure method boundaries in non-render client contexts
→ Then [methods/frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md](methods/frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md) for sync payload handling and atom ownership boundaries
→ Then [methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md](methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md) for hook and ViewModel boundaries
→ Then [methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md](methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md) for template/organism composition contracts
→ Then [methods/frontend/CONTROLLER_INFRA_CONTRACTS.md](methods/frontend/CONTROLLER_INFRA_CONTRACTS.md) for side-effect ownership and infrastructure boundaries

### "I'm adding a new feature to the backend"
→ Read [methods/backend/BASE_CONTEXT_CONTRACTS.md](methods/backend/BASE_CONTEXT_CONTRACTS.md) before creating or migrating a context entry module
→ Use the `roblox-implement-feature` skill with the `new-context` reference to scaffold a full bounded context
→ Use the `roblox-implement-feature` skill with the `new-service` reference to add a single service inside an existing context
→ Reference [architecture/backend/DDD.md](architecture/backend/DDD.md) for which layer the service belongs to

### "I want Codex to implement a feature end-to-end"
→ Use the `roblox-implement-feature` skill
→ It requires pre-reading relevant architecture docs and context files before edits
→ Use the `roblox-plan` skill first if you want a plan before implementation

### "I need to migrate a context or ECS layer to base classes"
-> Read [methods/backend/BASE_CONTEXT_CONTRACTS.md](methods/backend/BASE_CONTEXT_CONTRACTS.md) for BaseContext migration rules
-> Read the relevant ECS method contracts for world, component, factory, system, phase, and instance-reveal boundaries
-> Use the `roblox-migrate-context-ecs` skill to migrate context registry wiring, ECS infrastructure, and ECS-backed runtime instance services to the shared base classes

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

### "I need to create or improve a .codex/ markdown file"
→ Use the `codex-create-md` skill to author a new method contract, architecture doc, skill, or command template
→ Use the `codex-improve-md` skill to audit and rewrite an existing MD that may be missing sections or using prose where bullets belong
→ Both skills enforce the formatting and content standards established for this project

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
| [architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md](architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md) | Non-render client context architecture for controllers, application commands/queries, and infrastructure runtime boundaries |
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

### Methods Contracts
| File | Purpose |
|------|---------|
| [methods/METHODS_INDEX.md](methods/METHODS_INDEX.md) | Index of low-level method contracts for implementation work |
| [methods/PLAN_DEVELOPMENT.md](methods/PLAN_DEVELOPMENT.md) | Standard output contract and rubric gates for GDD + implementation planning |
| [methods/backend/CONTEXT_BOUNDARIES.md](methods/backend/CONTEXT_BOUNDARIES.md) | Context boundary categories, Catch ownership, and bridge-only prohibitions |
| [methods/backend/BASE_CONTEXT_CONTRACTS.md](methods/backend/BASE_CONTEXT_CONTRACTS.md) | BaseContext service-table configuration, module specs, caching, lifecycle delegation, and migration rules |
| [methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md](methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md) | Registry lifecycle rules for owned modules, cross-context dependencies, and Start ordering |
| [methods/backend/ASSET_ACCESS_CONTRACTS.md](methods/backend/ASSET_ACCESS_CONTRACTS.md) | AssetFetcher registry lifecycle and prohibition on direct asset tree traversal |
| [methods/backend/APPLICATION_CONTRACTS.md](methods/backend/APPLICATION_CONTRACTS.md) | Command/Query flow, Result return contracts, and dependency prohibitions |
| [methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md](methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md) | Policy/spec contracts, candidate ownership, and restore-path rules |
| [methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md) | Infrastructure Result boundaries, lifecycle ownership, and sync placement rules |
| [methods/frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md](methods/frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md) | Sync payload handling, infrastructure atom ownership, and read/write hook boundaries |
| [methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md](methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md) | Controller/application/infrastructure method contracts for non-render client contexts |
| [methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md](methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md) | Read/write hook separation and ViewModel contracts for frontend methods |
| [methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md](methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md) | Template/organism composition contracts and animation guardrails |
| [methods/frontend/CONTROLLER_INFRA_CONTRACTS.md](methods/frontend/CONTROLLER_INFRA_CONTRACTS.md) | Controller side-effect ownership and frontend infrastructure boundaries |
| [methods/ECS/COMPONENT_RULES.md](methods/ECS/COMPONENT_RULES.md) | ECS component rules: pure data, Authoritative/Derived labels, frozen registries |
| [methods/ECS/ENTITY_FACTORY_RULES.md](methods/ECS/ENTITY_FACTORY_RULES.md) | Entity factory rules: only JECS mutation surface, typed accessors, deferred destruction |
| [methods/ECS/SYSTEM_RULES.md](methods/ECS/SYSTEM_RULES.md) | System rules: stateless, read/write declaration, single owner per authoritative component |
| [methods/ECS/WORLD_ISOLATION_RULES.md](methods/ECS/WORLD_ISOLATION_RULES.md) | World isolation rules: one world per bounded context, Infrastructure-only JECS access |
| [methods/ECS/PHASE_AND_EXECUTION_RULES.md](methods/ECS/PHASE_AND_EXECUTION_RULES.md) | Phase rules: Input→Logic→Sync→Render order, deferred flush, Derived writes in Sync only |
| [methods/ECS/TAG_RULES.md](methods/ECS/TAG_RULES.md) | ECS tag rules: binary state markers, world:entity() creation, PascalCaseTag naming |
| [methods/ECS/INSTANCE_REVEAL_RULES.md](methods/ECS/INSTANCE_REVEAL_RULES.md) | Instance reveal rules: Attributes and CollectionService tags as the server→client discovery channel |
| [methods/ECS/ECS_PERSISTENCE_RULES.md](methods/ECS/ECS_PERSISTENCE_RULES.md) | ECS persistence rules: ECS↔ProfileStore bridge, Save/Load/Delete shape, serialization and lifecycle |


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
| `roblox-migrate-context-ecs` | Migrate backend context registry wiring, ECS infrastructure, and ECS-backed runtime instance services to BaseContext, BaseECS, and BaseInstanceFactory base classes. |
| `roblox-review` | Review code against DDD, error handling, state sync, and style rules. |
| `roblox-refactor-better` | Analyze or refactor code for readability, abstraction quality, naming, control flow, and project fit. |
| `roblox-suggest-result` | Suggest or apply the backend Result/error-handling pattern and boundary rules. |
| `roblox-documentation` | Update project docs or inline comments using Moonwave and readability rules. |
| `codex-create-md` | Create a new `.codex/` markdown file (method contract, architecture doc, skill, or command) following this project's formatting and content standards. |
| `codex-improve-md` | Audit and rewrite an existing `.codex/` markdown file — adds missing sections, converts prose to bullets, tightens constraints, and fixes frontmatter. |

## Repo-Local Templates

| Template area | What it does |
|-------|-------------|
| `.codex/commands/` | Prompt template archive. Codex does not automatically expose these as slash commands. Prefer matching skills when available. |
| `.codex/agents/` | Legacy agent prompt archive kept for migration reference. |

