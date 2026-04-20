# Backend Architecture

This is the root document for backend architecture. Read this first, then follow the links to specific topics.

## Overview

The backend follows **Domain-Driven Design (DDD)** with three distinct layers per bounded context, orchestrated by the **Knit** service framework. Game entities are managed via **JECS** (Entity-Component-System), player data is persisted with **ProfileStore**, and state is replicated to clients via **Charm-sync**.

## Documents

- [DDD.md](DDD.md) - DDD layers, bounded contexts, constructor injection, immutable domain services
- [KNIT.md](KNIT.md) - Knit service framework, auto-discovery, lifecycle, client remotes
- [ERROR_HANDLING.md](ERROR_HANDLING.md) - Success/data pattern, assertions vs validation, logging format, error constants
- [STATE_SYNC.md](STATE_SYNC.md) - Deep clone rules, nested table sync, centralized mutation pattern
- [SYSTEMS.md](SYSTEMS.md) - JECS, ProfileStore, key libraries

## Layer Summary

```
Application Layer    → Orchestrates domain logic, handles business workflows
                       (Validation, service coordination, state management)

Domain Layer        → Pure business logic, domain entities
                       (Validators, calculators, value objects)
                       NO external dependencies, NO side effects

Infrastructure      → Technical implementation details
Layer               (JECS world, entity storage, data persistence)
```

## Project Structure (Backend)

```
src/
├── ServerScriptService/
│   ├── Runtime.server.lua              # Server entry point - starts Knit services
│   ├── Data/                           # Data persistence
│   │   ├── DataInit.server.lua         # Data initialization on player join
│   │   ├── DataManager.lua             # Manages player profiles/data
│   │   ├── Template.lua                # Data template schema
│   │   └── Services/
│   │       └── PlayerDataLoader.lua    # Loads/processes player data
│   │
│   └── Contexts/
│       └── [ContextName]/              # Feature/domain context (bounded context)
│           ├── [ContextName]Context.lua # Main Knit service
│           ├── Application/Services/    # Orchestration layer
│           ├── [ContextName]Domain/    # Domain logic
│           │   ├── Services/            # Domain validators, calculators
│           │   └── ValueObjects/        # Domain value objects
│           ├── Infrastructure/Services/ # Entity/component creation
│           ├── Config/                  # Context configuration files
│           ├── Errors.lua               # Error message constants
│           └── Config/DebugLogger.lua   # (Optional) Debug logging utility
│
└── ReplicatedStorage/
    ├── Config/
    │   └── DebugConfig.lua             # Master debug switch
    ├── Packages/                       # Wally dependencies
    ├── Contexts/
    │   └── [ContextName]/
    │       ├── Config/                 # Context config files
    │       ├── Types/                  # Shared type definitions
    │       └── Sync/                   # State atoms
    └── Utilities/                      # Shared helpers
```

## Quick Rules

- Domain layer has **no side effects** and **no framework dependencies**
- All state mutations go through the **Infrastructure sync service** — never directly to atoms
- All error-prone operations return `(success: boolean, data/error)`
- Errors are logged **once** at the Application layer — never at the Context layer
- Getters that return atom state **must return a deep clone**
