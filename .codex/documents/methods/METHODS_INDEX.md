# Methods Contracts

Low-level method contracts for implementation work. These documents convert backend conventions into explicit pass/fail rules.

---

## Backend Contracts

- [backend/CONTEXT_BOUNDARIES.md](backend/CONTEXT_BOUNDARIES.md) - Context boundary method categories, Catch ownership, and bridge-only rules.
- [backend/BASE_CONTEXT_CONTRACTS.md](backend/BASE_CONTEXT_CONTRACTS.md) - BaseContext service-table configuration, module specs, caching, lifecycle delegation, and migration rules.
- [backend/BASE_APPLICATION_CONTRACTS.md](backend/BASE_APPLICATION_CONTRACTS.md) - BaseApplication/BaseCommand/BaseQuery constructor, dependency resolution, and event-name resolution contracts.
- [backend/BASE_PERSISTENCE_CONTRACTS.md](backend/BASE_PERSISTENCE_CONTRACTS.md) - BasePersistenceService profile access, path traversal/write, and Result boundary contracts.
- [backend/DEPENDENCY_REGISTRATION_CONTRACTS.md](backend/DEPENDENCY_REGISTRATION_CONTRACTS.md) - Registry lifecycle rules for owned modules vs cross-context dependencies.
- [backend/ASSET_ACCESS_CONTRACTS.md](backend/ASSET_ACCESS_CONTRACTS.md) - AssetFetcher registry requirements and prohibitions on direct asset traversal.
- [backend/APPLICATION_CONTRACTS.md](backend/APPLICATION_CONTRACTS.md) - Command and Query method contracts, execution flow, and dependency prohibitions.
- [backend/DOMAIN_POLICY_SPEC_CONTRACTS.md](backend/DOMAIN_POLICY_SPEC_CONTRACTS.md) - Policy/spec method contracts, candidate ownership, and restore-path requirements.
- [backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md) - Infrastructure runtime/persistence method contracts, lifecycle ownership, and mutation boundaries.
- [backend/CONTEXT_REGISTRY_CONTRACTS.md](backend/CONTEXT_REGISTRY_CONTRACTS.md) - KnitInit registry setup rules: registration order (Infra→Domain→App), InitAll timing, cross-context dependency placement, and connection ownership.
- [backend/DOMAIN_VALIDATOR_CONTRACTS.md](backend/DOMAIN_VALIDATOR_CONTRACTS.md) - Domain validator authoring rules: Result return contract, Ensure vs Err usage, private helper shape, and Infrastructure read prohibition.


---
## Frontend Contracts

- [frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md](frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md) - Client context method contracts for non-render controller/application/infrastructure boundaries.
- [frontend/HOOK_VIEWMODEL_CONTRACTS.md](frontend/HOOK_VIEWMODEL_CONTRACTS.md) - Read/write hook separation and ViewModel method contracts.
- [frontend/TEMPLATE_ORGANISM_CONTRACTS.md](frontend/TEMPLATE_ORGANISM_CONTRACTS.md) - Template/organism composition boundaries and animation guardrails.
- [frontend/CONTROLLER_INFRA_CONTRACTS.md](frontend/CONTROLLER_INFRA_CONTRACTS.md) - Controller side-effect ownership and infrastructure boundary rules.
- [frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md](frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md) - Sync payload consumption, infrastructure atom ownership, and read/write hook boundaries.
- [frontend/SYNC_CLIENT_CONTRACTS.md](frontend/SYNC_CLIENT_CONTRACTS.md) - SyncClient authoring rules: BaseSyncClient inheritance, four-argument constructor contract, Start/GetAtom delegation, and lifecycle placement.


---
## Shared / Cross-Cutting Contracts

- [backend/EVENTS_CONTRACTS.md](backend/EVENTS_CONTRACTS.md) - GameEvents module authoring rules: `events`/`schemas` table structure, naming, schema types, and caller constraints.
- [backend/ERRORS_CONTRACTS.md](backend/ERRORS_CONTRACTS.md) - Per-context `Errors.lua` authoring rules: key naming, string prefixes, `table.freeze` requirement, Moonwave docs, and `Result.Err` usage.


---
## ECS Contracts

- [ECS/COMPONENT_RULES.md](ECS/COMPONENT_RULES.md) - ECS component rules: pure data, Authoritative/Derived labels, frozen registries.
- [ECS/ENTITY_FACTORY_RULES.md](ECS/ENTITY_FACTORY_RULES.md) - Entity factory rules: only JECS mutation surface, typed accessors, deferred destruction.
- [ECS/RUNTIME_OBJECT_BOUNDARIES.md](ECS/RUNTIME_OBJECT_BOUNDARIES.md) - Runtime ownership split for entity factories, instance factories, and game-object sync services.
- [ECS/SYSTEM_RULES.md](ECS/SYSTEM_RULES.md) - System rules: stateless, read/write declaration, single owner per authoritative component.
- [ECS/WORLD_ISOLATION_RULES.md](ECS/WORLD_ISOLATION_RULES.md) - World isolation rules: one world per bounded context, Infrastructure-only JECS access.
- [ECS/PHASE_AND_EXECUTION_RULES.md](ECS/PHASE_AND_EXECUTION_RULES.md) - Phase rules: Inputâ†’Logicâ†’Syncâ†’Render order, deferred flush, Derived writes in Sync only.
- [ECS/TAG_RULES.md](ECS/TAG_RULES.md) - ECS tag rules: binary state markers, world:entity() creation, PascalCaseTag naming.
- [ECS/INSTANCE_REVEAL_RULES.md](ECS/INSTANCE_REVEAL_RULES.md) - Instance reveal rules: Attributes and CollectionService tags as the serverâ†’client discovery channel.
- [ECS/ECS_PERSISTENCE_RULES.md](ECS/ECS_PERSISTENCE_RULES.md) - ECS persistence rules: ECSâ†”ProfileStore bridge, Save/Load/Delete shape, serialization and lifecycle.


---
## Planning Standards

- [PLAN_DEVELOPMENT.md](PLAN_DEVELOPMENT.md) - Required output contract, quality rubric, and approval gates for GDD + implementation planning.

---

## Usage

When adding or editing backend behavior:

1. Read the matching architecture docs first (`architecture/backend/*`).
2. Read the matching methods contract in this folder.
3. Treat `Prohibitions`, `Failure Signals`, and `Checklist` items as pass/fail requirements.

When adding or editing frontend behavior:

1. Read the matching architecture docs first (`architecture/frontend/*`).
2. Read the matching frontend methods contract in this folder.
3. Treat `Prohibitions`, `Failure Signals`, and `Checklist` items as pass/fail requirements.
