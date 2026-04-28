# Backend Architecture

This is the root document for backend architecture. Read this first, then follow the links to the specific backend topic you need.

---

## Overview

- The backend follows **Domain-Driven Design (DDD)** with three layers per bounded context, orchestrated by the **Knit** service framework.
- Game entities are managed through **JECS** with the ECS ownership split documented in [ECS_OVERVIEW.md](ECS_OVERVIEW.md).
- Player data is persisted with **ProfileStore**.
- State is replicated to clients with **Charm-sync**.
- Shared technical helpers live in `ReplicatedStorage/Utilities/` and are documented in [UTILITY_USE.md](UTILITY_USE.md).
- Persistence lifecycle is event-driven through `GameEvents.Events.Persistence`:
  - `Persistence.ProfileLoaded` -> contexts hydrate runtime state from profile data.
  - `Persistence.ProfileSaving` -> contexts flush runtime state into `profile.Data`.
  - `Persistence.PlayerReady` -> the player is fully initialized across all registered context loaders.

---

## Core Rules

- The backend follows **DDD** with a strict layer order: Application -> Domain -> Infrastructure.
- The Domain layer has no side effects and no framework dependencies.
- All state mutations go through the Infrastructure sync service; never write directly to atoms.
- Context `*SyncService` modules belong in `Infrastructure/Persistence/`, not `Infrastructure/Services/`.
- All error-prone operations return `Result<T>` and use `Ok` / `Err` for success and failure.
- Errors are logged once at the Application layer; never at the Context layer.
- Getters that return atom state must return a deep clone.
- Context hydration and save should run from `GameEvents.Events.Persistence` (`ProfileLoaded`, `ProfileSaving`), not ad hoc player join or leave handlers.

---

## Layer Summary

```text
Application Layer    -> Orchestrates domain logic, handles business workflows
                       (validation, service coordination, state management)

Domain Layer         -> Pure business logic, domain entities
                       (validators, calculators, value objects)
                       No external dependencies and no side effects

Infrastructure       -> Technical implementation details
Layer                (JECS world, entity storage, data persistence)
```

ECS-specific ownership inside Infrastructure is further split in [ECS_OVERVIEW.md](ECS_OVERVIEW.md).

---

## Backend Structure

```text
src/
|-- ServerScriptService/
|   |-- Runtime.server.lua              # Server entry point - starts Knit services
|   |-- Persistence/                    # Profile persistence + player lifecycle orchestration
|   |   |-- ProfileInit.server.lua      # Boots ProfileStore + SessionManager
|   |   |-- SessionManager.lua          # Session lifecycle; emits persistence game events
|   |   |-- ProfileManager.lua          # Active profile repository/accessor
|   |   |-- PlayerLifecycleManager.lua  # Context loader readiness + PlayerReady emit
|   |   `-- Template.lua                # Profile schema/defaults
|   |
|   `-- Contexts/
|       `-- [ContextName]/              # Feature/domain context (bounded context)
|           |-- [ContextName]Context.lua # Main Knit service
|           |-- Application/
|           |   |-- Commands/            # Write operations
|           |   `-- Queries/             # Read operations
|           |-- [ContextName]Domain/    # Domain logic
|           |   |-- Services/            # Domain validators, calculators
|           |   `-- ValueObjects/        # Domain value objects
|           |-- Infrastructure/
|           |   |-- Persistence/         # ProfileStore + context SyncService modules (atom sync)
|           |   `-- Services/            # Non-persistence runtime services
|           |-- Config/                  # Context configuration files
|           |-- Errors.lua               # Error message constants
|
`-- ReplicatedStorage/
    |-- Config/
    |   `-- DebugConfig.lua             # Master debug switch
    |-- Packages/                       # Wally dependencies
    |-- Contexts/
    |   `-- [ContextName]/
    |       |-- Config/                 # Context config files
    |       |-- Types/                  # Shared type definitions
    |       `-- Sync/                   # State atoms
    `-- Utilities/                      # Shared helpers
```

---

## Documents

- [DDD.md](DDD.md) - DDD layers, bounded contexts, constructor injection, immutable domain services
- [KNIT.md](KNIT.md) - Knit service framework, auto-discovery, lifecycle, client remotes
- [ERROR_HANDLING.md](ERROR_HANDLING.md) - Success/data pattern, assertions vs validation, logging format, error constants
- [STATE_SYNC.md](STATE_SYNC.md) - Deep clone rules, nested table sync, centralized mutation pattern
- [ECS_OVERVIEW.md](ECS_OVERVIEW.md) - ECS roles, boundaries, sync placement, and persistence linkage
- [UTILITY_USE.md](UTILITY_USE.md) - Shared utility usage, ECS helper boundaries, and placement guidance
- [SYSTEMS.md](SYSTEMS.md) - JECS, ProfileStore, debug logging, key libraries

---

## Key References

- [architecture/ARCHITECTURE.md](../ARCHITECTURE.md) - Root architecture index
- [backend/DDD.md](DDD.md) - DDD layer rules and bounded-context structure
- [backend/ECS_OVERVIEW.md](ECS_OVERVIEW.md) - ECS ownership and runtime boundaries
- [backend/SYSTEMS.md](SYSTEMS.md) - Runtime systems, persistence flow, and library references
