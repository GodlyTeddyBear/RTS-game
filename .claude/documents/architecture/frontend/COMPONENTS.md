# Components (Atomic Design)

Components follow Atomic Design — smaller primitives compose into larger structures. The hierarchy determines where a component lives and when it can be extracted to a global location.

```
Templates (Full screens) — always feature-local
    ↓ uses
Organisms (Feature-specific complex components) — always feature-local
    ↓ uses
Molecules (Named sub-regions) — feature-local first, global only after 3+ features
    ↓ uses
Atoms (Primitives) — global in App/
    ↓ uses
Layouts (Structural containers) — global in App/
```

---

## Atoms — `App/Presentation/Atoms/`

Standalone UI primitives with no business logic. Button, Text, Frame, Icon.

**Extraction rule**: Only move to `App/Presentation/Atoms/` after a component is used across **3+ different features**. Keep it feature-local until then.

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
        [React.Event.Activated] = props[React.Event.Activated],
        [React.Event.MouseEnter] = function() setIsHovered(true) end,
        [React.Event.MouseLeave] = function() setIsHovered(false) end,
    })
end
```

---

## Molecules — `[Feature]/Presentation/Molecules/` or `App/Presentation/Molecules/`

Compositions of atoms that represent a self-contained named sub-region of a component. Examples: `QuantitySelector`, `ItemIconDisplay`, `RarityLabel`.

**Feature-local first**: Molecules do not need to be reused across features to justify extraction. Extract a molecule from an organism whenever a clearly named, cohesive region becomes large enough to obscure the organism's intent. The test: if you can give the region a meaningful name and it has its own props contract, it is a molecule.

Place the molecule in `[Feature]/Presentation/Molecules/` until it is used in 3+ features. At that point, move it to `App/Presentation/Molecules/`.

```lua
-- Shop/Presentation/Molecules/QuantitySelector.lua
-- Extracted from ShopDetailPanelView — self-contained +/- controls with cost label
local function QuantitySelector(props: TQuantitySelectorProps)
    return e("Frame", { ... }, {
        AddButton = ...,
        Amount = ...,
        MinusButton = ...,
        Cost = ...,
    })
end
```

**Extraction rule for `App/`**: Only after used in 3+ different features.

---

## Layouts — `App/Presentation/Layouts/`

Structural containers with no visual styling — FlexLayout, GridLayout, ScrollLayout. Pure layout logic, no content.

---

## Organisms — `[Feature]/Presentation/Organisms/`

Complex feature-specific components that combine atoms and molecules. Always feature-local — organisms are never shared. Extract sub-regions into molecules when the organism grows beyond ~60 lines in its return block.

Organisms that own a grid, list, or scrollable container with complex child-building logic should be extracted as dedicated organisms (e.g. `ShopGrid`) rather than building children inline in the template. The template passes data props; the organism owns the layout and child construction.

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
        }),
    })
end
```

---

## Templates — `[Feature]/Presentation/Templates/`

Full screens or major layout sections. **Always feature-local — never shared.**

Templates are the primary place where feature-level hooks are called and ViewModels are constructed. They pass the resulting data down to organisms via props.

Exception: for animation-heavy organisms, a thin wrapper component may call a UI controller hook (for example `useSidePanelController`) and pass the result to a pure `*View` component. See `SCREEN_TEMPLATES.md` and `ANIMATION_PATTERN.md`.

```lua
-- Counter/Presentation/Templates/CounterScreen.lua
local function CounterScreen()
    local counterState = useCounter()
    local actions = useCounterActions()

    local viewModel = React.useMemo(function()
        return CounterViewModel.fromAtomData(counterState)
    end, { counterState })

    return React.createElement(Frame, { Size = UDim2.fromScale(1, 1) }, {
        Display = React.createElement(CounterDisplay, { viewModel = viewModel }),
        Controls = React.createElement(CounterControls, { actions = actions }),
    })
end
```

---

## Sizing and Positioning Conventions

- **Use `UDim2.fromScale`** for sizes and positions wherever the element should stretch with its parent.
- **Use `UDim2.fromOffset`** only for fixed-pixel elements (e.g. icons, close buttons) that must never stretch.
- **`AnchorPoint` should always be `Vector2.new(0.5, 0.5)`** — center the element on its position point. Avoid `(0, 0)` or `(1, 0.5)` anchors which make layout math fragile.
- **Position via scale**, not pixel offset, unless the parent has a fixed pixel size.

```lua
-- Correct: centered popup panel
Panel = e("Frame", {
    Size = UDim2.fromScale(0.5, 0.6),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
})

-- Correct: fixed-size close button anchored to top-right of parent
CloseButton = e("TextButton", {
    Size = UDim2.fromOffset(28, 20),
    Position = UDim2.fromScale(1, 0.5),
    AnchorPoint = Vector2.new(1, 0.5),
})
```

---

## Extraction Decision Tree

```
Is this a clearly named sub-region of an organism (icon area, quantity controls, rarity label)?
  → Extract to [Feature]/Presentation/Molecules/ even if only used once

Is this molecule used in 1–2 features?
  → Keep it in [Feature]/Presentation/Molecules/

Is this molecule/atom used in 3+ features?
  → Extract to App/Presentation/Atoms/ or App/Presentation/Molecules/

Is this a grid/list/container with complex child-building logic inside a template?
  → Extract to [Feature]/Presentation/Organisms/ and pass data props from the template
```

When in doubt, keep it local. Premature extraction to `App/` creates coupling — but extraction within a feature is always encouraged for readability.
