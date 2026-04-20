# Frontend Architecture Guide

This document describes the frontend architecture pattern used in this project. It aligns DDD principles with React component architecture, Atomic Design, and Feature-Sliced Design.

## Quick Summary

The frontend follows a **3-layer architecture** per feature:

```
Presentation Layer (React Components)
         ↓
Application Layer (Hooks, ViewModels)
         ↓
Infrastructure Layer (State, Services)
```

Key principles:
- **One feature = One feature slice** (Counter, Party, Inventory, Combat, etc.)
- **Atoms → Organisms → Templates** (Atomic Design hierarchy)
- **Read hooks ≠ Write hooks** (Separation of concerns)
- **No business logic in components** (ViewModels handle transformation)

## Project Structure

```
StarterPlayerScripts/
├── ClientRuntime.client.lua          # Entry point - Knit auto-discovery
│
└── Contexts/
    ├── App/                          # Global UI infrastructure
    │   ├── AppController.lua         # Knit controller - mounts React root
    │   ├── Infrastructure/
    │   │   └── Services/
    │   ├── Application/
    │   │   └── Hooks/               # Global hooks (useTheme, etc.)
    │   └── Presentation/
    │       ├── Atoms/               # Global primitives (Button, Text, Frame, Icon)
    │       ├── Molecules/           # Global compositions (IconButton, Tooltip)
    │       ├── Layouts/             # Layout containers (FlexLayout, GridLayout)
    │       └── App.lua              # Root component
    │
    ├── Counter/                      # Feature slice (demo)
    │   ├── Infrastructure/
    │   │   └── CounterAtom.lua      # Local Charm atom
    │   ├── Application/
    │   │   ├── Hooks/
    │   │   │   ├── useCounter.lua                   # Read atom
    │   │   │   └── useCounterActions.lua           # Mutations
    │   │   └── ViewModels/
    │   │       └── CounterViewModel.lua            # Transform data
    │   └── Presentation/
    │       ├── Organisms/
    │       │   ├── CounterDisplay.lua              # Shows count
    │       │   └── CounterControls.lua             # Action buttons
    │       ├── Templates/
    │       │   └── CounterScreen.lua               # Main screen
    │       └── index.lua                           # Feature export
    │
    └── [Future Feature Slices]/
        ├── Party/
        ├── Inventory/
        └── Combat/
```

## Architecture Layers

### Infrastructure Layer

**Responsibility**: State management, backend communication

**File Pattern**: `[Feature]/Infrastructure/[Name]Atom.lua`, `[Feature]/Infrastructure/[Name]SyncClient.lua`

**Examples:**
- `CounterAtom.lua` - Creates and exports Charm atom
- `[Feature]SyncClient.lua` - Initializes Charm-sync client for backend state
- Service clients that wrap Knit service calls

```lua
-- Counter/Infrastructure/CounterAtom.lua
local Charm = require(ReplicatedStorage.Packages.Charm)

export type TCounterState = {
    Count: number,
    TotalClicks: number,
    LastUpdated: number,
}

local function createCounterAtom()
    return Charm.atom({
        Count = 0,
        TotalClicks = 0,
        LastUpdated = os.time(),
    } :: TCounterState)
end

return createCounterAtom
```

### Application Layer

**Responsibility**: Orchestration, state access, business logic, data transformation

**Three sub-components:**

#### 1. Hooks (Reusable stateful logic)

**Read Hooks** - Subscribe to atoms, return state reactively
```lua
-- Counter/Application/Hooks/useCounter.lua
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local createCounterAtom = require(script.Parent.Parent.Parent.Infrastructure.CounterAtom)

local counterAtom = nil

function useCounter()
    if counterAtom == nil then
        counterAtom = createCounterAtom()
    end
    return ReactCharm.useAtom(counterAtom)
end

return useCounter
```

**Write Hooks** - Expose mutation functions, don't subscribe to state
```lua
-- Counter/Application/Hooks/useCounterActions.lua
function useCounterActions()
    return {
        increment = function()
            local current = counterAtom()
            counterAtom({
                Count = current.Count + 1,
                TotalClicks = current.TotalClicks + 1,
                LastUpdated = os.time(),
            })
        end,
        -- decrement, reset, etc.
    }
end
```

**Rules:**
- Read hooks use `ReactCharm.useAtom()` or `useState()`
- Write hooks DON'T subscribe to atoms (prevent re-renders)
- Separate read and write concerns

#### 2. ViewModels - Transform data for UI display

```lua
-- Counter/Application/ViewModels/CounterViewModel.lua
export type TCounterViewData = {
    Count: number,
    TotalClicks: number,
    DisplayCount: string,
    DisplayClicks: string,
    DisplayLastUpdated: string,
}

function CounterViewModel.fromAtomData(atomData)
    -- Calculate time elapsed
    local secondsElapsed = os.time() - atomData.LastUpdated
    local displayTime = secondsElapsed < 60
        and (secondsElapsed .. "s ago")
        or (math.floor(secondsElapsed / 60) .. "m ago")

    return table.freeze({
        Count = atomData.Count,
        TotalClicks = atomData.TotalClicks,
        DisplayCount = "Count: " .. tostring(atomData.Count),
        DisplayClicks = "Total Clicks: " .. tostring(atomData.TotalClicks),
        DisplayLastUpdated = "Updated: " .. displayTime,
    } :: TCounterViewData)
end
```

**Rules:**
- Takes raw atom data as input
- Returns frozen table (immutable)
- Formats strings, calculations, derived values
- No mutations of input data

#### 3. Selectors (Memoized data selection)

For complex state filtering/selection:
```lua
-- Pattern: select only specific data from large atoms
function selectCounterById(counters, counterId)
    return counters[counterId]
end
```

### Presentation Layer

**Responsibility**: Pure rendering, user interaction

**Atomic Design Hierarchy:**

```
Templates (Full screens)
    ↓ uses
Organisms (Feature-specific complex components)
    ↓ uses
Molecules (Reusable compositions) [Global in App/]
    ↓ uses
Atoms (Primitives) [Global in App/]
    ↓ uses
Layouts (Structural containers) [Global in App/]
```

#### Atoms (Global primitives in App/Presentation/Atoms/)

**Rule**: Extract ONLY when used across 3+ different features

```lua
-- App/Presentation/Atoms/Button.lua
local function Button(props)
    local isHovered, setIsHovered = React.useState(false)

    return React.createElement("TextButton", {
        Text = props.Text or "Button",
        Size = props.Size or UDim2.fromOffset(100, 40),
        BackgroundColor3 = if isHovered
            then Color3.fromRGB(100, 100, 100)
            else Color3.fromRGB(60, 60, 60),
        TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255),
        [React.Event.Activated] = props[React.Event.Activated],
        [React.Event.MouseEnter] = function() setIsHovered(true) end,
        [React.Event.MouseLeave] = function() setIsHovered(false) end,
    })
end
```

#### Organisms (Feature-specific in [Feature]/Presentation/Organisms/)

**Rule**: Start feature-local, extract to App/ only after used in 3+ features

```lua
-- Counter/Presentation/Organisms/CounterDisplay.lua
local function CounterDisplay(props)
    return React.createElement(Frame, {
        Size = UDim2.fromScale(1, 0),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
    }, {
        Layout = React.createElement(FlexLayout, { Direction = "Column", Gap = 12 }),
        CountLabel = React.createElement(Text, {
            Text = props.viewModel.DisplayCount,
            FontSize = 48,
            TextColor3 = Color3.fromRGB(100, 200, 255),
        }),
        -- More children...
    })
end
```

#### Templates (Feature-specific layouts in [Feature]/Presentation/Templates/)

**Rule**: ALWAYS feature-local, NEVER shared

```lua
-- Counter/Presentation/Templates/CounterScreen.lua
local function CounterScreen()
    local counterState = useCounter()
    local actions = useCounterActions()

    local viewModel = React.useMemo(function()
        return CounterViewModel.fromAtomData(counterState)
    end, { counterState })

    return React.createElement(Frame, { Size = UDim2.fromScale(1, 1) }, {
        Header = React.createElement(Text, { Text = "Counter Demo", FontSize = 32 }),
        Display = React.createElement(CounterDisplay, { viewModel = viewModel }),
        Controls = React.createElement(CounterControls, { actions = actions }),
    })
end
```

## Dependency Rules

### Allowed (Top → Down)

```
Templates ↓ can use
Organisms ↓ can use
Molecules ↓ can use
Atoms ↓ can use
Layouts
```

```
Presentation → uses → Application → uses → Infrastructure → uses → ReplicatedStorage
```

```
[Feature] → uses → App → uses → ReplicatedStorage
```

### Prohibited

- ❌ `Feature → Feature` (Counter cannot import Party)
- ❌ `Presentation → Infrastructure` (Components cannot call services directly)
- ❌ `Lower → Upper` (Atoms cannot import Organisms)
- ❌ `App → [Feature]` (Global components cannot import feature components)
- ❌ `Application → Presentation` (Hooks cannot import components)

## Anti-Patterns

### 1. Business Logic in Components

❌ **BAD:**
```lua
function CounterCard(props)
    local counter = useCounter()
    -- BAD: Calculation in component
    local displayValue = "Count: " .. tostring(counter.Count + 100)
    -- BAD: Calling Knit service directly
    local service = Knit.GetService("CounterContext")
end
```

✅ **GOOD:**
```lua
-- ViewModels handle transformation
local viewModel = CounterViewModel.fromAtomData(counter)

-- Mutation hooks handle service calls
local actions = useCounterActions()
```

### 2. Direct Atom Mutations in Components

❌ **BAD:**
```lua
function IncrementButton()
    local onClick = function()
        local current = counterAtom()
        current.Count = current.Count + 1  -- Direct mutation!
        counterAtom(current)
    end
end
```

✅ **GOOD:**
```lua
function IncrementButton()
    local actions = useCounterActions()
    local onClick = actions.increment
end
```

### 3. Premature Component Extraction

❌ **BAD:**
```
App/Presentation/Atoms/
├── Button.lua
├── CustomButton.lua
├── SpecialButton.lua
├── DialogButton.lua
└── ... (15 more unused buttons)
```

✅ **GOOD:**
```
Counter/Presentation/Organisms/
├── CounterButton.lua  -- 1st use

[Later, in Party feature]
Party/Presentation/Organisms/
├── PartyButton.lua    -- 2nd use

[Later, in Inventory feature]
Inventory/Presentation/Organisms/
├── InventoryButton.lua -- 3rd use

-- NOW extract to App/Presentation/Atoms/Button.lua
```

### 4. Feature Coupling Through Imports

❌ **BAD:**
```lua
-- Counter/Presentation/Templates/CounterScreen.lua
local PartyList = require(StarterPlayerScripts.Contexts.Party.Presentation.Organisms.PartyList)

function CounterScreen()
    return React.createElement(PartyList, {})  -- Couples features!
end
```

✅ **GOOD:**
```lua
-- Let backend provide joined data, or use global navigation state
local useNavigation = require(StarterPlayerScripts.Contexts.App.Application.Hooks.useNavigation)
```

### 5. Mixing Read and Write Hooks

❌ **BAD:**
```lua
function useCounterData()
    local state = ReactCharm.useAtom(counterAtom)

    return state, {
        increment = function()
            -- Updates cause re-renders unnecessarily
        end
    }
end
```

✅ **GOOD:**
```lua
-- Separate hooks
function useCounter()
    return ReactCharm.useAtom(counterAtom)  -- Read only
end

function useCounterActions()
    return { increment = function() ... end }  -- Write only
end
```

## Implementation Checklist

### Creating a New Feature Slice

- [ ] Create `[Feature]/` folder
- [ ] Create `Infrastructure/[Name]Atom.lua` or SyncClient
- [ ] Create `Application/Hooks/use[Feature]Data.lua` (read)
- [ ] Create `Application/Hooks/use[Feature]Actions.lua` (write)
- [ ] Create `Application/ViewModels/[Entity]ViewModel.lua`
- [ ] Create `Presentation/Organisms/[Component].lua` (feature-specific)
- [ ] Create `Presentation/Templates/[Screen].lua` (main screen)
- [ ] Create `Presentation/index.lua` (feature export)
- [ ] Update `App/Presentation/App.lua` to render feature
- [ ] Build and test

### Code Quality Checks

- [ ] No business logic in Presentation components
- [ ] Hooks are separated (read vs write)
- [ ] ViewModels return frozen tables
- [ ] Organisms are feature-local
- [ ] Templates are feature-local
- [ ] No cross-feature imports
- [ ] All files use `--!strict` mode
- [ ] Proper dependency direction maintained

## Integration with Backend

### Backend State Sync (Future)

When integrating with backend services:

```lua
-- [Feature]/Infrastructure/[Feature]SyncClient.lua
local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])

function [Feature]SyncClient:Start(BlinkClient)
    local syncer = CharmSync.client({
        atoms = {
            entityData = self.EntityAtom,
        },
    })

    BlinkClient.Sync.On(function(payload)
        syncer:sync(payload)
    end)
end
```

### Backend Service Calls (Future)

Mutation hooks will call Knit services:

```lua
-- [Feature]/Application/Hooks/use[Feature]Actions.lua
function use[Feature]Actions()
    local service = Knit.GetService("[Feature]Context")

    return {
        createEntity = function(data)
            return service.Client.CreateEntity:CallAsync(data)
        end,
    }
end
```

## Example: Counter Feature (Complete)

See the Counter feature implementation in `StarterPlayerScripts/Contexts/Counter/` for a working example of:
- Infrastructure layer with Charm atom
- Application layer with separated hooks
- ViewModel pattern for data transformation
- Presentation layer with organisms and templates
- Proper feature integration

This is the template to copy for all future features.

## See Also

- [CLAUDE.md](CLAUDE.md) - Backend architecture and project conventions
- [Plan File](C:\Users\Alex\.claude\plans\calm-purring-walrus.md) - Detailed architecture decisions and tradeoff analysis
