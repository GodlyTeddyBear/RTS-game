# CLAUDE.md

This file is the entry point for Claude Code. It contains behavioral rules and navigation pointers.
All detailed architecture, patterns, and style documentation lives in `.claude/documents/`.

---

## How Claude Should Work With This Project

### Implement, Don't Suggest
Default to **implementing changes** rather than suggesting them. If intent is unclear, infer the most useful action and proceed — use tools to discover missing details instead of asking.

### Use Parallel Tool Calls
When multiple tools have no dependencies between them, call all of them in the same message. Never sequence what can be parallelized.

### Never Speculate About Code
Read files before making claims about them. If a question is about a specific file or function, open it first. Never describe code you haven't read.

### Read Moonwave Before Documentation Work
Before writing or editing doc comments/public API docs, read `.claude/documents/coding-style/MOONWAVE.md` in the current session and follow its syntax/structure rules exactly.

### Read Memories Before Implementation Work
Before planning or editing code, read `.claude/MEMORIES.md` in the current session and apply relevant lessons.

### Minimize Over-Engineering
Only make changes that are directly requested or clearly necessary. Don't add error handling, refactor surrounding code, or introduce abstractions beyond the immediate task.

### Confirm Before Risky Actions
For destructive, irreversible, or externally visible actions (force push, deleting files, sending messages, modifying CI), confirm with the user first. Approving one instance does not authorize future instances.

---

## Quick Commands

```bash
wally install       # Install dependencies
rojo serve          # Start dev server (live sync with Studio)
rojo build -o "PlaceName.rbxlx"  # Build place file
selene src/         # Run linter
```

**Slash commands:**
- `/new-context <Name>` — Scaffold a full DDD bounded context
- `/new-service <Context> <Layer> <Name>` — Add a service to an existing context
- `/new-feature <Name>` — Scaffold a frontend feature slice
- `/plan-mode2 <feature request>` — Generate a strict, execution-ready Roblox implementation plan (no code)
- `/review <path>` — Review code against architecture and style rules
- `/lint <path>` — Run Selene and summarize findings
- `/improve-ui <path>` — Analyze UI structure and suggest separation-focused refactors
- `/analyze-patterns <path> ["target pattern"]` — Extract patterns from a folder; add a target pattern for full migration analysis
- `/refactor-better <path>` — Analyze a file or folder for readability, abstraction, and library-usage issues

**Agents:**
- `context-reviewer` — Deep DDD review of a full bounded context
- `feature-planner` — Plan a new feature through analysis, questioning, and architecture options
- `ui-extractor` — Identify reusable component opportunities across UI screens
- `figma-importer` — Safely integrate a Figma-generated React-Lua import

---

## Project Structure

```
src/
├── ServerScriptService/
│   ├── Runtime.server.lua              # Server entry point — starts Knit
│   ├── Persistence/                    # Profile persistence & player lifecycle
│   │   ├── ProfileInit.server.lua      # ProfileStore session lifecycle + events
│   │   ├── ProfileManager.lua          # Thin profile accessor (GetData/ResetData)
│   │   ├── PlayerLifecycleManager.lua  # Readiness gate for context loading
│   │   └── Template.lua                # Data schema/defaults
│   └── Contexts/
│       └── [ContextName]/
│           ├── [ContextName]Context.lua  # Knit service — pure pass-through
│           ├── Errors.lua                # Error message constants
│           ├── Application/
│           │   ├── Commands/             # Write operations (full DDD stack)
│           │   └── Queries/              # Read operations (Infrastructure only)
│           ├── [ContextName]Domain/
│           │   ├── Services/             # Validators, calculators
│           │   ├── Specs/                # Composable eligibility rules
│           │   ├── Policies/             # State fetch + spec evaluation
│           │   └── ValueObjects/         # Immutable domain objects
│           ├── Infrastructure/
│           │   ├── ECS/                 # JECS world, component registries, entity factories
│           │   ├── Persistence/         # ProfileStore, Charm atom sync
│           │   └── Services/            # Roblox instance work, game logic
│           └── Config/DebugLogger.lua
│
├── ReplicatedStorage/
│   ├── Config/DebugConfig.lua           # Master debug switch
│   ├── Packages/                        # Wally dependencies
│   ├── Contexts/[ContextName]/
│   │   ├── Config/
│   │   ├── Types/
│   │   └── Sync/
│   └── Utilities/
│
└── StarterPlayerScripts/
    ├── ClientRuntime.client.lua         # Client entry point — starts Knit
    └── Contexts/
        ├── App/                         # Global UI infrastructure
        │   ├── AppController.lua        # Mounts React root
        │   └── Presentation/
        │       ├── Atoms/               # Global primitives (3+ feature rule)
        │       ├── Molecules/           # Global compositions (3+ feature rule)
        │       ├── Layouts/             # Structural containers
        │       └── App.lua
        └── [FeatureName]/              # Feature slice
            ├── Infrastructure/          # Atoms, sync clients
            ├── Application/
            │   ├── Hooks/               # Read hooks + write hooks (separate files)
            │   └── ViewModels/          # Data transformation for UI
            ├── Presentation/
            │   ├── Organisms/           # Feature-specific components
            │   ├── Templates/           # Screens — ALWAYS feature-local
            │   └── index.lua
            └── Types/
```

---

## Knowledge Base

All detailed documentation is in `.claude/documents/`.

**Read docs when the task requires it — not upfront:**

| If you're doing... | Read first |
|--------------------|-----------|
| Splitting a large config, event registry, or data file | `architecture/DATA_FILES.md` |
| Adding/modifying a backend service | `architecture/backend/DDD.md`, `architecture/backend/CQRS.md` |
| Adding eligibility checks or policies | `architecture/backend/POLICIES_AND_SPECS.md` |
| Handling errors or logging | `architecture/backend/ERROR_HANDLING.md` |
| Writing to or reading from atoms | `architecture/backend/STATE_SYNC.md` |
| Creating a new context or service | `architecture/backend/KNIT.md` |
| Adding/modifying a frontend feature | `architecture/frontend/FRONTEND.md` |
| Working with hooks or ViewModels | `architecture/frontend/HOOKS.md` |
| Adding or extracting a component | `architecture/frontend/COMPONENTS.md` |
| Unsure if an import is allowed | `architecture/frontend/DEPENDENCY_RULES.md` |
| Unsure about frontend layer dependencies | `architecture/frontend/LAYERS.md` |
| Reviewing any code | `architecture/backend/` + relevant frontend docs |
| Writing or reviewing any function | `coding-style/READABILITY.md` |
| Writing doc comments or public API docs | `coding-style/MOONWAVE.md` |
| Designing a non-trivial service interaction | `patterns/PROGRAMMING_PATTERNS.md` |
| Unsure where to look | `ONBOARDING.md` |

| Document | Contents |
|----------|----------|
| [.claude/documents/ONBOARDING.md](.claude/documents/ONBOARDING.md) | Task-based navigation map for all docs |
| [.claude/documents/AGENT_RULES.md](.claude/documents/AGENT_RULES.md) | Behavioral rules for Claude — overrides defaults |
| [.claude/documents/architecture/ARCHITECTURE.md](.claude/documents/architecture/ARCHITECTURE.md) | Root index: backend + frontend |
| [.claude/documents/architecture/DATA_FILES.md](.claude/documents/architecture/DATA_FILES.md) | Splitting large data files — partitioned vs structured aggregation |
| [.claude/documents/architecture/backend/BACKEND.md](.claude/documents/architecture/backend/BACKEND.md) | Backend architecture root index |
| [.claude/documents/architecture/backend/DDD.md](.claude/documents/architecture/backend/DDD.md) | Layers, constructor injection, value objects, pass-through pattern |
| [.claude/documents/architecture/backend/CQRS.md](.claude/documents/architecture/backend/CQRS.md) | Command/Query separation, asymmetric layers, dependency rules |
| [.claude/documents/architecture/backend/ERROR_HANDLING.md](.claude/documents/architecture/backend/ERROR_HANDLING.md) | Success/data pattern, logging rule, assertions vs validation |
| [.claude/documents/architecture/backend/STATE_SYNC.md](.claude/documents/architecture/backend/STATE_SYNC.md) | Deep clone, targeted cloning, centralized mutation |
| [.claude/documents/architecture/backend/KNIT.md](.claude/documents/architecture/backend/KNIT.md) | Auto-discovery, lifecycle, client remotes |
| [.claude/documents/architecture/backend/SYSTEMS.md](.claude/documents/architecture/backend/SYSTEMS.md) | JECS, ProfileStore, debug config, libraries |
| [.claude/documents/architecture/backend/POLICIES_AND_SPECS.md](.claude/documents/architecture/backend/POLICIES_AND_SPECS.md) | Specifications, Policies, eligibility checking, candidate types |
| [.claude/documents/architecture/frontend/FRONTEND.md](.claude/documents/architecture/frontend/FRONTEND.md) | Feature slice overview |
| [.claude/documents/architecture/frontend/LAYERS.md](.claude/documents/architecture/frontend/LAYERS.md) | Frontend layer dependency rules — flow direction |
| [.claude/documents/architecture/frontend/HOOKS.md](.claude/documents/architecture/frontend/HOOKS.md) | Read/write separation, ViewModels, Selectors |
| [.claude/documents/architecture/frontend/COMPONENTS.md](.claude/documents/architecture/frontend/COMPONENTS.md) | Atomic Design, extraction rule |
| [.claude/documents/architecture/frontend/DEPENDENCY_RULES.md](.claude/documents/architecture/frontend/DEPENDENCY_RULES.md) | Allowed and prohibited imports |
| [.claude/documents/architecture/frontend/ANTI_PATTERNS.md](.claude/documents/architecture/frontend/ANTI_PATTERNS.md) | Common mistakes and correct alternatives |
| [.claude/documents/coding-style/CODING_STYLE.md](.claude/documents/coding-style/CODING_STYLE.md) | Naming conventions, --!strict, type annotations |
| [.claude/documents/coding-style/IMMUTABILITY.md](.claude/documents/coding-style/IMMUTABILITY.md) | table.freeze rules |
| [.claude/documents/coding-style/READABILITY.md](.claude/documents/coding-style/READABILITY.md) | Composed methods, abstraction levels, stepdown rule, naming, tell-don't-ask |
| [.claude/documents/coding-style/LUAU_TYPES.md](.claude/documents/coding-style/LUAU_TYPES.md) | Luau type system patterns, generic chaining, recursive types, common solver issues |
| [.claude/documents/coding-style/MOONWAVE.md](.claude/documents/coding-style/MOONWAVE.md) | Moonwave doc comment syntax, luau-lsp hover docs, public API documentation |
| [.claude/documents/patterns/NEGATIVE_SPACE.md](.claude/documents/patterns/NEGATIVE_SPACE.md) | Failure handling by layer |
| [.claude/documents/patterns/DEBUG_LOGGING.md](.claude/documents/patterns/DEBUG_LOGGING.md) | DebugLogger usage and milestones |
| [.claude/documents/patterns/PROGRAMMING_PATTERNS.md](.claude/documents/patterns/PROGRAMMING_PATTERNS.md) | GoF design patterns adapted for Lua/Roblox DDD |
