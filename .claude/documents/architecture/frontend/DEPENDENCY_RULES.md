# Dependency Rules

## Allowed Directions

### Component hierarchy (top → down only)
```
Templates
  ↓ can use
Organisms
  ↓ can use
Molecules
  ↓ can use
Atoms
  ↓ can use
Layouts
```

### Layer hierarchy (top → down only)
```
Presentation → Application → Infrastructure → ReplicatedStorage
```

### Animated wrapper hierarchy
```
Presentation/[Component].lua (wrapper) → Application/Hooks/use[Component]Controller.lua
Presentation/[Component]View.lua (pure view) → Presentation-only dependencies
```

### Feature scope
```
[Feature] → App (global) → ReplicatedStorage
```

### Presentation public API
```
External consumer → [Feature]/Presentation/init.lua
```
Prefer `require(...[Feature].Presentation.init)` over deep imports into `Presentation/Templates/*`.

---

## Prohibited

| Import | Reason |
|---|---|
| `Feature → Feature` | Features are independent slices — Counter cannot import Party |
| `Presentation → Infrastructure` | Components cannot call services or access atoms directly |
| `Lower → Upper` | Atoms cannot import Organisms; Infrastructure cannot import Application |
| `App → [Feature]` | Global components cannot depend on feature-specific components |
| `Application → Presentation` | Hooks cannot import components |
| `Presentation/*View.lua → Application` | Pure view components must not import Application hooks |

---

## Examples

**Wrong — cross-feature import:**
```lua
-- Counter/Presentation/Templates/CounterScreen.lua
local PartyList = require(StarterPlayerScripts.Contexts.Party.Presentation.Organisms.PartyList)
-- ❌ Counter cannot import from Party
```

**Correct — use global state or backend-provided data:**
```lua
local useNavigation = require(StarterPlayerScripts.Contexts.App.Application.Hooks.useNavigation)
-- ✅ Both features can use the global App layer
```

**Wrong — component accessing infrastructure:**
```lua
-- Inside a component
local counterAtom = require(script.Parent.Parent.Infrastructure.CounterAtom)
local state = counterAtom()  -- ❌ Component bypasses Application layer
```

**Correct — component uses a hook:**
```lua
local useCounter = require(script.Parent.Parent.Application.Hooks.useCounter)
local state = useCounter()  -- ✅ Goes through Application layer
```

**Correct — wrapper uses UI controller hook, view stays pure:**
```lua
-- SidePanel.lua (wrapper)
local useSidePanelController = require(...Application.Hooks.useSidePanelController)
local SidePanelView = require(script.Parent.SidePanelView)
```

```lua
-- SidePanelView.lua (pure view)
-- ✅ no Application hook imports here
```

**Wrong — atom imports organism:**
```lua
-- App/Presentation/Atoms/Button.lua
local CounterDisplay = require(StarterPlayerScripts.Contexts.Counter.Presentation.Organisms.CounterDisplay)
-- ❌ Atom (lower) importing Organism (upper)
```

---

## Quick Reference

```
✅ Template uses Organism         (same feature, downward)
✅ Organism uses Atom             (global, downward)
✅ Hook uses Atom                 (Application → Infrastructure, downward)
✅ Feature uses App/Atoms         (Feature → App, allowed scope)
✅ Wrapper uses UI controller hook (Presentation wrapper → Application hook)

❌ Counter uses Party             (cross-feature)
❌ Component uses Atom directly   (Presentation → Infrastructure, skips Application)
❌ Atom uses Organism             (lower imports upper)
❌ App uses Counter               (global imports feature)
❌ Hook imports Component         (Application imports Presentation)
❌ Pure view imports hooks        (`*View.lua` should stay Presentation-only)
```
