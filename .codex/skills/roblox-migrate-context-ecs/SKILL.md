---
name: roblox-migrate-context-ecs
description: Use when Codex needs to migrate an existing Roblox backend context entry module, registry wiring, ECS layer, or runtime instance layer to this repo's BaseContext, BaseECSWorldService, BaseECSComponentRegistry, BaseECSEntityFactory, and BaseInstanceFactory patterns.
---

# Roblox Migrate Context ECS

- Use this skill to migrate existing Roblox + Luau backend contexts, ECS infrastructure, and ECS-backed runtime instance services to the shared base classes without changing public behavior.

---

## Workflow

1. Read the repo root `AGENTS.md`.
2. Read `.codex/MEMORIES.md` and `.codex/documents/ONBOARDING.md`.
3. Read the relevant BaseContext and ECS method contracts listed by onboarding.
4. Read the target context entry module and all target ECS/runtime instance files before making claims or edits.
5. Read current migrated examples:
- `src/ServerScriptService/Contexts/World/WorldContext.lua` for BaseContext configuration.
- `src/ServerScriptService/Contexts/Commander/Infrastructure/ECS/` for BaseECS inheritance patterns.
- `src/ReplicatedStorage/Utilities/BaseInstanceFactory.lua` and `src/ServerScriptService/Contexts/Enemy/Infrastructure/Services/EnemyInstanceFactory.lua` for runtime instance-factory inheritance patterns.
6. Follow `references/migrate-context-ecs.md` for the audit, migration, validation, and response contract.

---

## Requirements

- Preserve DDD/CQRS boundaries and Result-returning context APIs.
- Preserve JECS world isolation and infrastructure-only JECS access.
- Preserve the boundary between JECS entity ownership and Workspace instance ownership.
- Preserve public method names, signal contracts, persistence behavior, scheduler hooks, and teardown behavior.
- Replace only duplicated setup that is owned by the BaseContext, BaseECS, or BaseInstanceFactory base classes.
- Run targeted validation after edits when available.
