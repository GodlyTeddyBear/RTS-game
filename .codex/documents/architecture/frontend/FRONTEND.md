# Frontend Architecture

This is the root document for frontend architecture. Read this first, then follow the links to specific topics.

## Overview

The frontend uses **React** (via ReactRoblox) for UI rendering, **Charm** atoms for state management, and **Charm-sync** to receive replicated state from the server. It follows a **Feature-Sliced Design** where each feature is a self-contained slice with three internal layers.

## Documents

- [LAYERS.md](LAYERS.md) - 3-layer architecture: Infrastructure, Application, Presentation
- [COMPONENTS.md](COMPONENTS.md) - Atomic Design hierarchy: Atoms, Molecules, Organisms, Templates
- [HOOKS.md](HOOKS.md) - Read/write hook separation, ViewModels, Selectors
- [DESIGN.md](DESIGN.md) - Visual style creation, cards/panels, hierarchy, chrome, and interaction states
- [SCREEN_TEMPLATES.md](SCREEN_TEMPLATES.md) - Screen composition pattern and controller-hook split
- [ANIMATION_PATTERN.md](ANIMATION_PATTERN.md) - Animated component wrapper/controller/view split
- [UDIM_LAYOUT_RULES.md](UDIM_LAYOUT_RULES.md) - Use scale for layout; reserve offset for decorative pixel details
- [DEPENDENCY_RULES.md](DEPENDENCY_RULES.md) - Allowed and prohibited import directions
- [ANTI_PATTERNS.md](ANTI_PATTERNS.md) - Common mistakes and correct alternatives

## Layer Summary

```
Presentation Layer (React Components)
         ↓
Application Layer (Hooks, ViewModels)
         ↓
Infrastructure Layer (State, Services)
```

## Project Structure (Frontend)

```
StarterPlayerScripts/
├── ClientRuntime.client.lua          # Entry point - Knit auto-discovery
│
└── Contexts/
    ├── App/                          # Global UI infrastructure
    │   ├── AppController.lua         # Knit controller - mounts React root
    │   ├── Infrastructure/Services/
    │   ├── Application/Hooks/        # Global hooks (useTheme, etc.)
    │   └── Presentation/
    │       ├── Atoms/               # Global primitives (Button, Text, Frame, Icon)
    │       ├── Molecules/           # Global compositions (reused 3+ times)
    │       ├── Layouts/             # Layout containers (FlexLayout, GridLayout)
    │       └── App.lua              # Root component
    │
    └── [FeatureName]/               # Feature slice
        ├── [FeatureName]Controller.lua  # Optional Knit controller
        ├── Infrastructure/          # State atoms, sync clients
        ├── Application/
        │   ├── Hooks/               # Read hooks, write hooks, orchestration hooks
        │   │   ├── Sounds/          # Sound side-effect hooks (use[Feature]Sounds)
        │   │   └── Animations/      # Animation orchestration hooks (use[Component]Controller)
        │   └── ViewModels/          # Data transformation for UI
        ├── Presentation/
        │   ├── Molecules/           # Feature-local named sub-regions (before 3-feature threshold)
        │   ├── Organisms/           # Feature-specific complex components
        │   ├── Templates/           # Feature screens/layouts
        │   └── init.lua             # Feature root export
        └── Types/                   # Feature-specific types
```

## Key Principles

- **One feature = one feature slice** (Counter, Party, Inventory, Combat, etc.)
- **Read hooks ≠ Write hooks** — never mix state subscription with mutation in the same hook
- **No business logic in components** — ViewModels handle all data transformation
- **Design concept before UI implementation** — define visual role, hierarchy, surfaces, and interaction model before building screens
- **Screens stay composition-first** — use `use[Screen]Controller` hooks for orchestration
- **Screens/templates do not orchestrate animation primitives directly** — use shared animation hooks and controller hooks
- **Templates are always feature-local** — never shared between features
- **No cross-feature imports** — features cannot import from each other
- **Use `Presentation/init.lua` as a feature public entrypoint** for App-level mounting/imports
- **Sound side-effects belong in `Hooks/Sounds/`** — screen controllers delegate to a sounds hook, never call `useSoundActions` directly
- **Feature-local molecules are valid** — extract named sub-regions from organisms into `Presentation/Molecules/` without requiring cross-feature reuse
- **Grid/list organisms own their child-building logic** — templates pass data props to a grid organism; they do not construct children inline

## Counter Feature (Reference Implementation)

The Counter feature at `StarterPlayerScripts/Contexts/Counter/` is the canonical working example of all frontend patterns. Copy its structure when creating new features.
