# Backend Architecture

This is the root document for backend architecture. Read this first, then follow the links to specific topics.

---

## Overview

- The backend follows **Domain-Driven Design (DDD)** with three distinct layers per bounded context, orchestrated by the **Knit** service framework.
- Game entities are managed via **JECS** (Entity-Component-System), player data is persisted with **ProfileStore**, and state is replicated to clients via **Charm-sync**.
- Persistence lifecycle is event-driven via `GameEvents.Events.Persistence`:
- `Persistence.ProfileLoaded` -> contexts hydrate runtime state from profile data
- `Persistence.ProfileSaving` -> contexts flush runtime state into `profile.Data`
- `Persistence.PlayerReady` -> player is fully initialized across all registered context loaders

---

## Documents

- [DDD.md](DDD.md) - DDD layers, bounded contexts, constructor injection, immutable domain services
- [KNIT.md](KNIT.md) - Knit service framework, auto-discovery, lifecycle, client remotes
- [ERROR_HANDLING.md](ERROR_HANDLING.md) - Success/data pattern, assertions vs validation, logging format, error constants
- [STATE_SYNC.md](STATE_SYNC.md) - Deep clone rules, nested table sync, centralized mutation pattern
- [ECS_OVERVIEW.md](ECS_OVERVIEW.md) - ECS roles, boundaries, sync placement, and persistence linkage
- [UTILITY_USE.md](UTILITY_USE.md) - Shared utility usage, ECS helper boundaries, and placement guidance
- [SYSTEMS.md](SYSTEMS.md) - JECS, ProfileStore, key libraries

---

## Layer Summary

```text
Application Layer    -> Orchestrates domain logic, handles business workflows
                       (Validation, service coordination, state management)

Domain Layer         -> Pure business logic, domain entities
                       (Validators, calculators, value objects)
                       NO external dependencies, NO side effects

Infrastructure       -> Technical implementation details
Layer                (JECS world, entity storage, data persistence)
```

---

## Project Structure (Backend)

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
|           `-- Config/DebugLogger.lua   # (Optional) Debug logging utility
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

## Quick Rules

- Domain layer has **no side effects** and **no framework dependencies**
- All state mutations go through the **Infrastructure sync service** - never directly to atoms
- Context `*SyncService` modules belong in **Infrastructure/Persistence/**, not **Infrastructure/Services/**
- All error-prone operations return `(success: boolean, data/error)`
- Errors are logged **once** at the Application layer - never at the Context layer
- Getters that return atom state **must return a deep clone**
- Context hydration/save should run from `GameEvents.Events.Persistence` (`ProfileLoaded`, `ProfileSaving`), not ad-hoc player join/leave handlers
