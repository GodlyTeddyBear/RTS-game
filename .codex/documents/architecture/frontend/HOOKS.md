# Hooks, ViewModels, and Selectors

This document defines how frontend hooks, ViewModels, and selectors are structured.

- Read and write hooks must stay separate.
- ViewModels transform raw atom data into frozen UI-ready tables.
- Selectors extract only the slice of state a component needs.
- Controller hooks own orchestration, side effects, and screen-level coordination.

---

## Related Docs

- [LAYERS.md](LAYERS.md) for frontend layer boundaries.
- [COMPONENTS.md](COMPONENTS.md) for what belongs in Presentation.
- [ANTI_PATTERNS.md](ANTI_PATTERNS.md) for the mistakes this document is designed to prevent.
- [ANIMATION_PATTERN.md](ANIMATION_PATTERN.md) for animation-heavy controller splits.

---

## Hook Types

Every feature has two distinct hook types, and they must always be separate files.

| | Read Hook | Write Hook |
|---|---|---|
| Purpose | Subscribe to state and return current values | Expose mutation functions |
| Subscribes to atom? | Yes, via `ReactCharm.useAtom()` | No, never subscribes |
| Causes re-renders? | Yes, on state change | No |
| Returns | Current state | Table of functions |

- A hook that both subscribes and mutates causes the component to re-render every time it calls a mutation, even if the state did not change from the component's perspective.

---

## Read Hooks

- Read hooks subscribe to an atom and return state reactively.
- The component re-renders whenever the atom changes.

```lua
-- Counter/Application/Hooks/useCounter.lua
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local createCounterAtom = require(script.Parent.Parent.Parent.Infrastructure.CounterAtom)

local counterAtom = nil

local function useCounter()
    if counterAtom == nil then
        counterAtom = createCounterAtom()
    end
    return ReactCharm.useAtom(counterAtom)
end

return useCounter
```

---

## Write Hooks

- Write hooks return a table of mutation functions.
- Write hooks do not subscribe to the atom.
- This keeps the hook from triggering re-renders.

```lua
-- Counter/Application/Hooks/useCounterActions.lua
local function useCounterActions()
    return {
        increment = function()
            local current = counterAtom()
            counterAtom({
                Count = current.Count + 1,
                TotalClicks = current.TotalClicks + 1,
                LastUpdated = os.time(),
            })
        end,
        decrement = function()
            local current = counterAtom()
            counterAtom({
                Count = math.max(0, current.Count - 1),
                TotalClicks = current.TotalClicks + 1,
                LastUpdated = os.time(),
            })
        end,
        reset = function()
            counterAtom({
                Count = 0,
                TotalClicks = counterAtom().TotalClicks,
                LastUpdated = os.time(),
            })
        end,
    }
end

return useCounterActions
```

Write hooks that call backend services should still return mutation functions rather than subscribing to atoms.

```lua
function useFeatureActions()
    local service = Knit.GetService("FeatureContext")
    return {
        createEntity = function(data)
            return service.Client.CreateEntity:CallAsync(data)
        end,
    }
end
```

---

## ViewModels

- ViewModels transform raw atom data into a frozen, UI-ready table.
- ViewModels do not mutate input.
- ViewModels handle all string formatting, calculations, and derived values.
- ViewModels have no side effects.

```lua
-- Counter/Application/ViewModels/CounterViewModel.lua
export type TCounterViewData = {
    Count: number,
    DisplayCount: string,
    DisplayClicks: string,
    DisplayLastUpdated: string,
}

function CounterViewModel.fromAtomData(atomData)
    local secondsElapsed = os.time() - atomData.LastUpdated
    local displayTime = secondsElapsed < 60
        and (secondsElapsed .. "s ago")
        or (math.floor(secondsElapsed / 60) .. "m ago")

    return table.freeze({
        Count = atomData.Count,
        DisplayCount = "Count: " .. tostring(atomData.Count),
        DisplayClicks = "Total Clicks: " .. tostring(atomData.TotalClicks),
        DisplayLastUpdated = "Updated: " .. displayTime,
    } :: TCounterViewData)
end
```

ViewModels are constructed in Templates using `React.useMemo`.

```lua
local viewModel = React.useMemo(function()
    return CounterViewModel.fromAtomData(counterState)
end, { counterState })
```

---

## Selectors

- Use selector functions for complex atoms.
- Selectors extract only the relevant slice of state.
- This avoids re-rendering a component when unrelated parts of a large atom change.

```lua
-- Select only a specific counter by ID from a large atom
local function selectCounterById(counters, counterId)
    return counters[counterId]
end
```

---

## Hooks Folder Organization

- Group hooks by concern using sub-folders as the `Hooks/` folder grows.
- A flat layout is fine for small features.
- Start using sub-folders once a category has 2+ hooks.

```text
Application/Hooks/
  Sounds/                        <- sound-triggered hooks (useShopSounds, useCombatSounds)
  Animations/                    <- animation orchestration hooks (useShopDetailPanelController)
  use[Feature]ScreenController.lua <- orchestrator (stays at top level)
  use[Feature]Actions.lua        <- write hook
  use[Feature].lua               <- read hook
  use[Feature]Inventory.lua      <- proxy hooks to other contexts
```

### Sounds Hooks

- Sounds hooks wrap `useSoundActions` calls for a specific feature.
- Collect all sound callbacks, such as tab switch, purchase, and sell, into one hook and return them as named functions.
- The screen controller calls the sounds hook and delegates sound side effects to it.
- The screen controller does not call `useSoundActions` directly.

```lua
-- Shop/Application/Hooks/Sounds/useShopSounds.lua
local function useShopSounds(): TShopSounds
    local soundActions = useSoundActions()
    return {
        onTabSwitch = function(tab) soundActions.playTabSwitch(tab) end,
        onBuy = function() soundActions.playButtonClick("buy"); soundActions.playPurchase() end,
        onSell = function() soundActions.playButtonClick("sell"); soundActions.playSell() end,
    }
end
```

### Animation Hooks

- Animation hooks own refs, springs, hover springs, reduced-motion checks, and `useCountUp` values for a specific animated organism.
- Animated organisms consume them through a thin wrapper component, not through the screen controller.
- See [ANIMATION_PATTERN.md](ANIMATION_PATTERN.md).

---

## Screen Controller Hooks

- For screen-level orchestration, create a dedicated hook such as `useGameViewController`.
- The screen template stays focused on composition.
- The controller hook owns local screen state and side effects.
- Keep hook bodies thin by moving behavior into module-level helper functions.
- Use this when screens start accumulating nested handlers, delayed navigation, or chained side effects.

```lua
-- Presentation/Screens/GameView.lua
local controller = useGameViewController()
return React.createElement(GameHUD, {
    OnToggleMenu = controller.onToggleMenu,
    OnNavigateFromMenu = controller.onNavigateFromMenu,
    OnOpenSettings = controller.onOpenSettings,
})
```

```lua
-- Application/Hooks/useGameViewController.lua
local function useGameViewController()
    local isMenuOpen, setIsMenuOpen = React.useState(false)
    -- wire dependencies and return callbacks
    return {
        isMenuOpen = isMenuOpen,
        onToggleMenu = ...,
        onNavigateToFeature = ...,
    }
end
```

---

## UI Controller Hooks

- UI orchestration hooks are valid in the Application layer even when they are not domain or business hooks.
- Use these for animation orchestration, refs, imperatively animated targets, and stable callback composition passed to pure view components.
- Keep orchestration hooks free of render trees.
- Keep view components free of orchestration hooks.
- Prefer stable callbacks and cleanup for delayed tasks or animations.

Recommended split for animated organisms:

- Wrapper component in Presentation (`SidePanel.lua`)
- UI controller hook in Application (`useSidePanelController.lua`)
- Pure view in Presentation (`SidePanelView.lua`)

---

## New Feature Checklist

- [ ] `[Feature]/Application/Hooks/use[Feature].lua` - read hook
- [ ] `[Feature]/Application/Hooks/use[Feature]Actions.lua` - write hook
- [ ] `[Feature]/Application/ViewModels/[Entity]ViewModel.lua` - data transform
- [ ] Read and write hooks are in separate files
- [ ] Write hook does not call `ReactCharm.useAtom()`
- [ ] ViewModel returns a frozen table
- [ ] Sound side effects are in `Hooks/Sounds/use[Feature]Sounds.lua`, not inline in the screen controller
- [ ] Animation orchestration for animated organisms is in `Hooks/Animations/use[Component]Controller.lua`
- [ ] Screen controller does not call `useSoundActions` directly and delegates to a sounds hook
