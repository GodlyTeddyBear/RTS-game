# Methods Contracts

Low-level method contracts for implementation work. These documents convert backend conventions into explicit pass/fail rules.

---

## Backend Contracts

- [backend/CONTEXT_BOUNDARIES.md](backend/CONTEXT_BOUNDARIES.md) - Context boundary method categories, Catch ownership, and bridge-only rules.
- [backend/DEPENDENCY_REGISTRATION_CONTRACTS.md](backend/DEPENDENCY_REGISTRATION_CONTRACTS.md) - Registry lifecycle rules for owned modules vs cross-context dependencies.
- [backend/ASSET_ACCESS_CONTRACTS.md](backend/ASSET_ACCESS_CONTRACTS.md) - AssetFetcher registry requirements and prohibitions on direct asset traversal.
- [backend/APPLICATION_CONTRACTS.md](backend/APPLICATION_CONTRACTS.md) - Command and Query method contracts, execution flow, and dependency prohibitions.
- [backend/DOMAIN_POLICY_SPEC_CONTRACTS.md](backend/DOMAIN_POLICY_SPEC_CONTRACTS.md) - Policy/spec method contracts, candidate ownership, and restore-path requirements.
- [backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md) - Infrastructure runtime/persistence method contracts, lifecycle ownership, and mutation boundaries.

## Frontend Contracts

- [frontend/HOOK_VIEWMODEL_CONTRACTS.md](frontend/HOOK_VIEWMODEL_CONTRACTS.md) - Read/write hook separation and ViewModel method contracts.
- [frontend/TEMPLATE_ORGANISM_CONTRACTS.md](frontend/TEMPLATE_ORGANISM_CONTRACTS.md) - Template/organism composition boundaries and animation guardrails.
- [frontend/CONTROLLER_INFRA_CONTRACTS.md](frontend/CONTROLLER_INFRA_CONTRACTS.md) - Controller side-effect ownership and infrastructure boundary rules.
- [frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md](frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md) - Sync payload consumption, infrastructure atom ownership, and read/write hook boundaries.

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
