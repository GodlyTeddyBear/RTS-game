# Anti-Patterns

## 1. Business Logic in Components

Components are for rendering only. Calculations, formatting, and service calls belong in ViewModels and hooks.

**Wrong:**
```lua
function CounterCard(props)
    local counter = useCounter()
    -- Calculation in component
    local displayValue = "Count: " .. tostring(counter.Count + 100)
    -- Calling Knit service directly from component
    local service = Knit.GetService("CounterContext")
    service:DoSomething()
end
```

**Correct:**
```lua
function CounterCard(props)
    -- ViewModel handles transformation
    local viewModel = props.viewModel  -- passed in from Template
    -- Write hook handles service calls
    local actions = useCounterActions()
end
```

---

## 2. Direct Atom Mutations in Components

Components never read or write atoms directly. Use hooks.

**Wrong:**
```lua
function IncrementButton()
    local counterAtom = require(Infrastructure.CounterAtom)
    local onClick = function()
        local current = counterAtom()
        current.Count = current.Count + 1  -- Direct mutation!
        counterAtom(current)
    end
end
```

**Correct:**
```lua
function IncrementButton(props)
    -- actions come from a write hook, passed via props
    return React.createElement("TextButton", {
        [React.Event.Activated] = props.actions.increment,
    })
end
```

---

## 3. Premature Component Extraction

Don't move a component to `App/Presentation/Atoms/` the first time you write it. Wait until it's genuinely needed in 3+ features.

**Wrong:**
```lua
-- Created for Counter, immediately put in global atoms
App/Presentation/Atoms/CounterButton.lua  -- Only used in Counter!
```

**Correct:**
```lua
-- 1st use: keep feature-local
Counter/Presentation/Organisms/CounterButton.lua

-- 2nd use: still keep local, duplicate is acceptable
Party/Presentation/Organisms/PartyButton.lua

-- 3rd use: now extract
App/Presentation/Atoms/Button.lua
```

---

## 4. Feature Coupling Through Imports

Features are independent. One feature must never import from another.

**Wrong:**
```lua
-- Counter importing from Party
local PartyList = require(StarterPlayerScripts.Contexts.Party.Presentation.Organisms.PartyList)
```

**Correct:**

Use the global `App` layer for shared state, or let the backend provide combined data via a sync atom.

---

## 5. Mixing Read and Write in One Hook

A hook that both subscribes to state and exposes mutations causes the component to re-render on every mutation call, regardless of whether the displayed data changed.

**Wrong:**
```lua
function useCounterData()
    local state = ReactCharm.useAtom(counterAtom)  -- Subscribes
    return state, {
        increment = function() ... end              -- Also mutates
    }
end
```

**Correct:**
```lua
-- Separate files, separate concerns
function useCounter()
    return ReactCharm.useAtom(counterAtom)  -- Read only
end

function useCounterActions()
    return { increment = function() ... end }  -- Write only, no subscription
end
```

---

## 6. Skipping the ViewModel

Passing raw atom state directly to a component and letting the component format it is business logic in the Presentation layer.

**Wrong:**
```lua
-- Template passes raw state
local state = useCounter()
React.createElement(CounterDisplay, { state = state })

-- Component formats it
function CounterDisplay(props)
    local text = "Count: " .. tostring(props.state.Count)  -- Formatting in component!
end
```

**Correct:**
```lua
-- Template builds ViewModel
local state = useCounter()
local viewModel = React.useMemo(function()
    return CounterViewModel.fromAtomData(state)
end, { state })

React.createElement(CounterDisplay, { viewModel = viewModel })

-- Component just renders
function CounterDisplay(props)
    local text = props.viewModel.DisplayCount  -- Already formatted
end
```

---

## 7. Side Effects in Presentational Components

Molecules/organisms should not call action hooks that trigger side effects (sound, navigation sequencing, delayed transitions). They should emit intent via props.

**Wrong:**
```lua
function MenuList(props)
    local soundActions = useSoundActions()
    return React.createElement(MenuItem, {
        OnActivated = function()
            soundActions.playTabSwitch("Shop")
            props.OnNavigate("Shop")
        end,
    })
end
```

**Correct:**
```lua
function MenuList(props)
    return React.createElement(MenuItem, {
        OnActivated = function()
            props.OnNavigate("Shop")
        end,
    })
end
```

Controller hook handles side effects:
```lua
function useGameViewController()
    return {
        onNavigateFromMenu = function(featureName)
            soundActions.playTabSwitch(featureName)
            navigateToFeature(featureName)
        end,
    }
end
```

---

## 8. Unused Props Across Component Boundaries

Passing props that are never read creates misleading APIs and maintenance overhead.

**Wrong:**
```lua
-- Parent passes IsOpen and OnClose
React.createElement(SidePanel, {
    IsOpen = isOpen,
    OnClose = onClose,
})
```

```lua
-- Child never uses IsOpen/OnClose
function SidePanel(props)
    return React.createElement("Frame", { ... })
end
```

**Correct:**
```lua
React.createElement(SidePanel, {
    OnNavigateFromMenu = onNavigateFromMenu,
    OnExitGame = onExitGame,
})
```

Keep prop contracts minimal and truthful.
