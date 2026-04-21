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

## Document Table
| File | Purpose |
|------|---------|
| [.codex/documents/methods/METHODS_INDEX.md](.codex/documents/methods/METHODS_INDEX.md) | Index for backend/frontend method-contract docs. |
| [.codex/documents/methods/PLAN_DEVELOPMENT.md](.codex/documents/methods/PLAN_DEVELOPMENT.md) | Standard output contract and rubric gates for GDD + implementation planning. |
| [.codex/documents/methods/backend/CONTEXT_BOUNDARIES.md](.codex/documents/methods/backend/CONTEXT_BOUNDARIES.md) | Context boundary method categories, Catch ownership, and bridge-only rules. |
| [.codex/documents/methods/backend/APPLICATION_CONTRACTS.md](.codex/documents/methods/backend/APPLICATION_CONTRACTS.md) | Application Command/Query method contracts and prohibitions. |
| [.codex/documents/methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md](.codex/documents/methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md) | Domain policy/spec method contracts and restore requirements. |
| [.codex/documents/methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](.codex/documents/methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md) | Infrastructure runtime/persistence boundaries, lifecycle ownership, and sync placement. |
| [.codex/documents/methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md](.codex/documents/methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md) | Frontend hook and ViewModel method contracts. |
| [.codex/documents/methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md](.codex/documents/methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md) | Frontend template/organism composition and animation boundary contracts. |
| [.codex/documents/methods/frontend/CONTROLLER_INFRA_CONTRACTS.md](.codex/documents/methods/frontend/CONTROLLER_INFRA_CONTRACTS.md) | Frontend controller side-effect and infrastructure boundary contracts. |
| [.codex/documents/methods/ECS/COMPONENT_RULES.md](.codex/documents/methods/ECS/COMPONENT_RULES.md) | ECS component rules: pure data, authority labels (Authoritative/Derived), frozen registries, tags. |
| [.codex/documents/methods/ECS/ENTITY_FACTORY_RULES.md](.codex/documents/methods/ECS/ENTITY_FACTORY_RULES.md) | Entity factory rules: only JECS mutation surface, typed accessors, deferred destruction. |
| [.codex/documents/methods/ECS/SYSTEM_RULES.md](.codex/documents/methods/ECS/SYSTEM_RULES.md) | System rules: stateless, read/write declaration, single owner per authoritative component, one phase. |
| [.codex/documents/methods/ECS/WORLD_ISOLATION_RULES.md](.codex/documents/methods/ECS/WORLD_ISOLATION_RULES.md) | World isolation rules: one world per bounded context, Infrastructure-only JECS access. |
| [.codex/documents/methods/ECS/PHASE_AND_EXECUTION_RULES.md](.codex/documents/methods/ECS/PHASE_AND_EXECUTION_RULES.md) | Phase and execution rules: Input→Logic→Sync→Render order, deferred flush, Derived writes in Sync only. |
| [.codex/documents/methods/ECS/TAG_RULES.md](.codex/documents/methods/ECS/TAG_RULES.md) | ECS tag rules: binary state markers, world:entity() creation, PascalCaseTag naming, query usage. |
| [.codex/documents/methods/ECS/INSTANCE_REVEAL_RULES.md](.codex/documents/methods/ECS/INSTANCE_REVEAL_RULES.md) | Instance reveal rules: Attributes and CollectionService tags as the server→client discovery channel. |
| [.codex/documents/methods/ECS/ECS_PERSISTENCE_RULES.md](.codex/documents/methods/ECS/ECS_PERSISTENCE_RULES.md) | ECS persistence rules: ECS↔ProfileStore bridge, Save/Load/Delete shape, serialization and lifecycle. |
