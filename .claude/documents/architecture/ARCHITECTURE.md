# Architecture

This is the root index for all architecture documentation.

## Backend

Server-side architecture: DDD layers, Knit, JECS, ProfileStore, state sync, error handling.

- [backend/BACKEND.md](backend/BACKEND.md) - Overview, project structure, quick rules
- [backend/DDD.md](backend/DDD.md) - DDD layers, bounded contexts, constructor injection, value objects
- [backend/KNIT.md](backend/KNIT.md) - Knit framework, auto-discovery, lifecycle, client remotes
- [backend/ERROR_HANDLING.md](backend/ERROR_HANDLING.md) - Success/data pattern, assertions, logging, error constants
- [backend/CQRS.md](backend/CQRS.md) - Command/Query separation, asymmetric layers, dependency rules
- [backend/STATE_SYNC.md](backend/STATE_SYNC.md) - Deep clone rules, nested table sync, centralized mutation
- [backend/SYSTEMS.md](backend/SYSTEMS.md) - JECS, ProfileStore, debug logging, key libraries
- [backend/POLICIES_AND_SPECS.md](backend/POLICIES_AND_SPECS.md) - Specifications, Policies, eligibility checking, candidate types

## Data Files

Conventions for splitting large data files (configs, event registries, dialogue trees) into folder modules.

- [DATA_FILES.md](DATA_FILES.md) - When to split, Pattern A (partitioned data), Pattern B (structured aggregation), rules
- [UNLOCK_REGISTRY.md](UNLOCK_REGISTRY.md) - Context-owned unlock definitions merged into UnlockConfig

## Frontend

Client-side architecture: React, Charm atoms, feature slices, Atomic Design, hooks.

- [frontend/FRONTEND.md](frontend/FRONTEND.md) - Overview, project structure, key principles
- [frontend/LAYERS.md](frontend/LAYERS.md) - Infrastructure, Application, Presentation layers
- [frontend/COMPONENTS.md](frontend/COMPONENTS.md) - Atomic Design: Atoms, Molecules, Organisms, Templates
- [frontend/HOOKS.md](frontend/HOOKS.md) - Read/write hook separation, ViewModels, Selectors
- [frontend/DEPENDENCY_RULES.md](frontend/DEPENDENCY_RULES.md) - Allowed and prohibited import directions
- [frontend/ANTI_PATTERNS.md](frontend/ANTI_PATTERNS.md) - Common mistakes and correct alternatives
