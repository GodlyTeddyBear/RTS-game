# AGENTS

This file is the repo-level policy entry point for Codex.

---

## Source Of Truth

- Treat `.codex/` as the primary source of truth for repo guidance.
- Read the relevant `.codex` docs before planning, editing, or answering about repo behavior.
- If a root-level doc conflicts with a `.codex` doc, follow the `.codex` doc.
- Do not invent workflow rules when a canonical `.codex` document already exists.

---

## Mandatory Read Order

- Read this file before planning or editing the codebase.
- Read [MEMORIES.md](.codex/MEMORIES.md) before any planning or implementation work.
- Read [ONBOARDING.md](.codex/documents/ONBOARDING.md) before choosing architecture, style, or method docs.
- Use [ONBOARDING.md](.codex/documents/ONBOARDING.md) as the routing map; do not guess at the next doc.
- Read [AGENT_RULES.md](.codex/documents/AGENT_RULES.md) before changing onboarding, workflow, or repo-wide behavior rules.

---

## Execution Rules

- Prefer implementing the requested change when the intent is clear.
- Do not speculate about code you have not read.
- Use repository docs and existing files to resolve unknowns before asking the user.
- Keep changes as small as the request allows.
- Do not add new abstractions, helpers, comments, or fallback behavior unless they are clearly required.
- Confirm before destructive or hard-to-reverse actions, including deletes, force-pushes, resets, or shared infrastructure changes.

---

## Workflow Routing

### Markdown work

- Use `codex-create-md` when creating a new `.codex/` markdown file.
- Use `codex-improve-md` when improving an existing `.codex/` markdown file.
- Read the target file and at least one sibling file of the same type before rewriting markdown.

### Reusable workflows

- Prefer a Codex skill when a matching skill exists.
- Use `.codex/commands/` files only when the user explicitly asks for that template or the template is the best match.
- Treat `.codex/commands/` as prompt templates, not automatic slash commands.

### Game and context work

- Use the matching Roblox skill before implementing a feature, refactor, migration, or review when one applies.
- Use [ONBOARDING.md](.codex/documents/ONBOARDING.md) to select the correct backend, frontend, ECS, method, or pattern docs before editing.

---

## Behavior Rules

- Keep changes aligned with documented architecture, style, and workflows.
- Minimize over-engineering.
- Do not leave dead code, unused compatibility hacks, or unnecessary scaffolding behind.
- Read the relevant docs before claiming a rule, behavior, or architecture detail.
- Keep responses concise and direct.

---

## Document Table

| File | Purpose |
|------|---------|
| [.codex/documents/methods/METHODS_INDEX.md](.codex/documents/methods/METHODS_INDEX.md) | Index for backend and frontend method-contract docs. |
| [.codex/documents/ONBOARDING.md](.codex/documents/ONBOARDING.md) | Routing map for selecting the next architecture, style, method, or pattern docs. |
| [.codex/documents/AGENT_RULES.md](.codex/documents/AGENT_RULES.md) | Behavioral rules for Codex in this project. |
| [.codex/documents/coding-style/CODING_STYLE.md](.codex/documents/coding-style/CODING_STYLE.md) | Navigation hub for coding-style docs. |
| [.codex/documents/coding-style/CODING_STYLE_GUIDE.md](.codex/documents/coding-style/CODING_STYLE_GUIDE.md) | Core coding-style rules for naming, types, tables, structure, and React API style. |
| [.codex/documents/methods/PLAN_DEVELOPMENT.md](.codex/documents/methods/PLAN_DEVELOPMENT.md) | Standard output contract and rubric gates for GDD and implementation planning. |
| [.codex/documents/methods/backend/CONTEXT_BOUNDARIES.md](.codex/documents/methods/backend/CONTEXT_BOUNDARIES.md) | Context boundary categories, Catch ownership, and bridge-only rules. |
| [.codex/documents/methods/backend/BASE_APPLICATION_CONTRACTS.md](.codex/documents/methods/backend/BASE_APPLICATION_CONTRACTS.md) | BaseApplication/BaseCommand/BaseQuery contracts for constructor identity, dependency resolution, and event-name resolution boundaries. |
| [.codex/documents/methods/backend/BASE_PERSISTENCE_CONTRACTS.md](.codex/documents/methods/backend/BASE_PERSISTENCE_CONTRACTS.md) | BasePersistenceService contracts for profile access, path traversal/write semantics, and Result boundary behavior. |
| [.codex/documents/methods/backend/APPLICATION_CONTRACTS.md](.codex/documents/methods/backend/APPLICATION_CONTRACTS.md) | Application command and query method contracts and prohibitions. |
| [.codex/documents/methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md](.codex/documents/methods/backend/DOMAIN_POLICY_SPEC_CONTRACTS.md) | Domain policy and spec contracts and restore requirements. |
| [.codex/documents/methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](.codex/documents/methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md) | Infrastructure runtime and persistence boundaries, lifecycle ownership, and sync placement. |
| [.codex/documents/methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md](.codex/documents/methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md) | Frontend hook and ViewModel method contracts. |
| [.codex/documents/methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md](.codex/documents/methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md) | Frontend template and organism composition and animation boundary contracts. |
| [.codex/documents/methods/frontend/CONTROLLER_INFRA_CONTRACTS.md](.codex/documents/methods/frontend/CONTROLLER_INFRA_CONTRACTS.md) | Frontend controller side-effect and infrastructure boundary contracts. |
| [.codex/documents/methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md](.codex/documents/methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md) | Client context method contracts for non-render controller, application, and infrastructure boundaries. |
| [.codex/documents/architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md](.codex/documents/architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md) | Non-render client context architecture for controllers, application commands and queries, and infrastructure runtime boundaries. |
| [.codex/documents/methods/ECS/COMPONENT_RULES.md](.codex/documents/methods/ECS/COMPONENT_RULES.md) | ECS component rules for pure data, authority labels, frozen registries, and tags. |
| [.codex/documents/methods/ECS/ENTITY_FACTORY_RULES.md](.codex/documents/methods/ECS/ENTITY_FACTORY_RULES.md) | Entity factory rules for JECS mutation surface, typed accessors, and deferred destruction. |
| [.codex/documents/methods/ECS/SYSTEM_RULES.md](.codex/documents/methods/ECS/SYSTEM_RULES.md) | System rules for statelessness, read/write declaration, and single-owner behavior. |
| [.codex/documents/methods/ECS/WORLD_ISOLATION_RULES.md](.codex/documents/methods/ECS/WORLD_ISOLATION_RULES.md) | World isolation rules for per-context world boundaries and Infrastructure-only JECS access. |
| [.codex/documents/methods/ECS/PHASE_AND_EXECUTION_RULES.md](.codex/documents/methods/ECS/PHASE_AND_EXECUTION_RULES.md) | ECS phase and execution order, deferred flush, and Derived write placement. |
| [.codex/documents/methods/ECS/TAG_RULES.md](.codex/documents/methods/ECS/TAG_RULES.md) | ECS tag rules for binary state markers, entity creation, and query usage. |
| [.codex/documents/methods/ECS/INSTANCE_REVEAL_RULES.md](.codex/documents/methods/ECS/INSTANCE_REVEAL_RULES.md) | Instance reveal rules for Attributes and CollectionService tags as the server to client discovery channel. |
| [.codex/documents/methods/ECS/ECS_PERSISTENCE_RULES.md](.codex/documents/methods/ECS/ECS_PERSISTENCE_RULES.md) | ECS persistence rules for the ECS and ProfileStore bridge, save and load shape, serialization, and lifecycle. |
