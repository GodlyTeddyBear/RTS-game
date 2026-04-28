# Onboarding

Use this file as the first routing step for any Codex agent in this repo. It tells you which docs to read next based on task purpose.

---

## Universal Preflight

Read these first for any task:

1. [AGENTS.md](../../AGENTS.md)
2. [MEMORIES.md](MEMORIES.md)
3. [ONBOARDING.md](ONBOARDING.md)

If the task touches code, also read the relevant canonical index before opening deeper docs:

- [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) for architecture work
- [methods/METHODS_INDEX.md](methods/METHODS_INDEX.md) for method-contract work
- [coding-style/CODING_STYLE.md](coding-style/CODING_STYLE.md) for style-sensitive changes

---

## Architecture Work

### If you are creating or restructuring data files or data modules

Read in this order:

1. [architecture/DATA_FILES.md](architecture/DATA_FILES.md)

Read these when relevant:

- [architecture/backend/BACKEND.md](architecture/backend/BACKEND.md) when the data module belongs to a backend context
- [architecture/backend/SYSTEMS.md](architecture/backend/SYSTEMS.md) when the data module drives backend runtime registries or event wiring
- [architecture/frontend/FRONTEND.md](architecture/frontend/FRONTEND.md) when the data module feeds frontend config or presentation data
- [methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md](methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md) when the data module participates in backend dependency registration
- [methods/backend/EVENTS_CONTRACTS.md](methods/backend/EVENTS_CONTRACTS.md) when the data module defines or aggregates event registries
- [methods/ECS/ECS_PERSISTENCE_RULES.md](methods/ECS/ECS_PERSISTENCE_RULES.md) when the data module is part of ECS persistence data

---

## Backend Work

If the task touches any backend code, read these first:

1. [architecture/backend/BACKEND.md](architecture/backend/BACKEND.md)
2. [architecture/backend/ERROR_HANDLING.md](architecture/backend/ERROR_HANDLING.md)
3. [methods/backend/CONTEXT_BOUNDARIES.md](methods/backend/CONTEXT_BOUNDARIES.md) when the task is context-specific
4. [methods/METHODS_INDEX.md](methods/METHODS_INDEX.md) when the task is method-contract specific

### If you are creating or changing a backend context

Read in this order:

1. [architecture/backend/BACKEND.md](architecture/backend/BACKEND.md)
2. [architecture/backend/DDD.md](architecture/backend/DDD.md)
3. [architecture/backend/ERROR_HANDLING.md](architecture/backend/ERROR_HANDLING.md)
4. [methods/backend/CONTEXT_BOUNDARIES.md](methods/backend/CONTEXT_BOUNDARIES.md)
5. [methods/backend/BASE_CONTEXT_CONTRACTS.md](methods/backend/BASE_CONTEXT_CONTRACTS.md)
6. [methods/backend/BASE_APPLICATION_CONTRACTS.md](methods/backend/BASE_APPLICATION_CONTRACTS.md)
7. [methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md](methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md)
8. [coding-style/CODING_STYLE.md](coding-style/CODING_STYLE.md)
9. [coding-style/READABILITY.md](coding-style/READABILITY.md)

Read these when relevant:

- [architecture/backend/CQRS.md](architecture/backend/CQRS.md) for commands, queries, or restore flow
- [architecture/backend/STATE_SYNC.md](architecture/backend/STATE_SYNC.md) for sync behavior
- [methods/backend/APPLICATION_CONTRACTS.md](methods/backend/APPLICATION_CONTRACTS.md) for command/query method boundaries
- [methods/backend/BASE_APPLICATION_CONTRACTS.md](methods/backend/BASE_APPLICATION_CONTRACTS.md) for shared BaseApplication/BaseCommand/BaseQuery helper contracts
- [methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md](methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md) for policies, specs, and restore-path rules
- [methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md) for runtime and persistence boundaries
- [methods/backend/BASE_PERSISTENCE_CONTRACTS.md](methods/backend/BASE_PERSISTENCE_CONTRACTS.md) for shared BasePersistenceService method boundaries
- [patterns/NEGATIVE_SPACE.md](patterns/NEGATIVE_SPACE.md) when the task includes failure handling, validation, or restore sequencing

### If you are working on backend infrastructure outside a context

Read in this order:

1. [architecture/backend/BACKEND.md](architecture/backend/BACKEND.md)
2. [architecture/backend/SYSTEMS.md](architecture/backend/SYSTEMS.md)
3. [architecture/backend/UTILITY_USE.md](architecture/backend/UTILITY_USE.md)
4. [methods/METHODS_INDEX.md](methods/METHODS_INDEX.md)

Then add the specific backend contract that matches the change:

- [methods/backend/ASSET_ACCESS_CONTRACTS.md](methods/backend/ASSET_ACCESS_CONTRACTS.md)
- [methods/backend/BASE_APPLICATION_CONTRACTS.md](methods/backend/BASE_APPLICATION_CONTRACTS.md)
- [methods/backend/BASE_PERSISTENCE_CONTRACTS.md](methods/backend/BASE_PERSISTENCE_CONTRACTS.md)
- [methods/backend/EVENTS_CONTRACTS.md](methods/backend/EVENTS_CONTRACTS.md)
- [methods/backend/DOMAIN_VALIDATOR_CONTRACTS.md](methods/backend/DOMAIN_VALIDATOR_CONTRACTS.md)
- [methods/backend/ERRORS_CONTRACTS.md](methods/backend/ERRORS_CONTRACTS.md)

---

## ECS Work

### If you are creating or changing ECS entities, systems, or persistence

Read in this order:

1. [methods/ECS/COMPONENT_RULES.md](methods/ECS/COMPONENT_RULES.md)
2. [methods/ECS/ENTITY_FACTORY_RULES.md](methods/ECS/ENTITY_FACTORY_RULES.md)
3. [methods/ECS/WORLD_ISOLATION_RULES.md](methods/ECS/WORLD_ISOLATION_RULES.md)
4. [methods/ECS/SYSTEM_RULES.md](methods/ECS/SYSTEM_RULES.md)
5. [methods/ECS/PHASE_AND_EXECUTION_RULES.md](methods/ECS/PHASE_AND_EXECUTION_RULES.md)
6. [methods/ECS/TAG_RULES.md](methods/ECS/TAG_RULES.md)
7. [methods/ECS/INSTANCE_REVEAL_RULES.md](methods/ECS/INSTANCE_REVEAL_RULES.md)
8. [methods/ECS/ECS_PERSISTENCE_RULES.md](methods/ECS/ECS_PERSISTENCE_RULES.md)

Read these when relevant:

- [architecture/backend/ECS_OVERVIEW.md](architecture/backend/ECS_OVERVIEW.md) for the high-level ECS role map
- [methods/ECS/RUNTIME_OBJECT_BOUNDARIES.md](methods/ECS/RUNTIME_OBJECT_BOUNDARIES.md) for entity, instance, and sync ownership

---

## Frontend Work

### If you are creating or changing a frontend feature

Read in this order:

1. [architecture/frontend/FRONTEND.md](architecture/frontend/FRONTEND.md)
2. [architecture/frontend/LAYERS.md](architecture/frontend/LAYERS.md)
3. [architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md](architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md) when the work touches controllers or non-render client contexts
4. [architecture/frontend/HOOKS.md](architecture/frontend/HOOKS.md)
5. [architecture/frontend/COMPONENTS.md](architecture/frontend/COMPONENTS.md)
6. [architecture/frontend/DESIGN.md](architecture/frontend/DESIGN.md)
7. [architecture/frontend/UDIM_LAYOUT_RULES.md](architecture/frontend/UDIM_LAYOUT_RULES.md)
8. [architecture/frontend/DEPENDENCY_RULES.md](architecture/frontend/DEPENDENCY_RULES.md)
9. [coding-style/CODING_STYLE.md](coding-style/CODING_STYLE.md)
10. [coding-style/READABILITY.md](coding-style/READABILITY.md)

Read these when relevant:

- [architecture/frontend/ANTI_PATTERNS.md](architecture/frontend/ANTI_PATTERNS.md) for common frontend mistakes
- [architecture/frontend/ANIMATION_PATTERN.md](architecture/frontend/ANIMATION_PATTERN.md) for motion-heavy UI work
- [architecture/frontend/SCREEN_TEMPLATES.md](architecture/frontend/SCREEN_TEMPLATES.md) for screen composition patterns
- [methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md](methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md) for controller/application/infrastructure method boundaries
- [methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md](methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md) for hook and ViewModel boundaries
- [methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md](methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md) for composition contracts
- [methods/frontend/CONTROLLER_INFRA_CONTRACTS.md](methods/frontend/CONTROLLER_INFRA_CONTRACTS.md) for side-effect ownership
- [methods/frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md](methods/frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md) for sync payload handling

---

## Planning Work

### If you are planning a feature or implementation

Read in this order:

1. [methods/PLAN_DEVELOPMENT.md](methods/PLAN_DEVELOPMENT.md)
2. `.codex/commands/plan-development.md` when you need the repo's plan template
3. `roblox-plan` skill

Use this path when you need an implementation-ready plan, not when you are already editing code.

---

## Documentation Work

### If you are creating or improving a `.codex/` markdown file

Read in this order:

1. [MEMORIES.md](MEMORIES.md)
2. [ONBOARDING.md](ONBOARDING.md)
3. [AGENTS.md](../../AGENTS.md)
4. The matching skill:
   - `codex-create-md` for a new file
   - `codex-improve-md` for an existing file

Read these when relevant:

- [coding-style/MOONWAVE.md](coding-style/MOONWAVE.md) before adding or editing doc comments or public API docs
- [methods/METHODS_INDEX.md](methods/METHODS_INDEX.md) when the document is a method contract
- [AGENT_RULES.md](AGENT_RULES.md) before changing onboarding or workflow guidance

### If you are reviewing or refactoring code

Read in this order:

1. `roblox-review` skill for reviews
2. `roblox-refactor-better` skill for readability or abstraction cleanup
3. [coding-style/READABILITY.md](coding-style/READABILITY.md)
4. [coding-style/CODING_STYLE.md](coding-style/CODING_STYLE.md)

Read these when relevant:

- [patterns/NEGATIVE_SPACE.md](patterns/NEGATIVE_SPACE.md) for failure handling and boundary placement
- [patterns/DEBUG_LOGGING.md](patterns/DEBUG_LOGGING.md) for logging behavior
- [architecture/backend/ERROR_HANDLING.md](architecture/backend/ERROR_HANDLING.md) if the code paths return `Result` values

---

## Maintenance Note

- Treat this file as a navigator, not a ruleset.
- Keep canonical rules in architecture, methods, coding-style, and patterns docs.
- When a new doc is added under `.codex/documents/`, update the relevant index or router instead of duplicating its contents here.
- Prefer linking to a canonical index first, then to the specific rule doc the task needs.
