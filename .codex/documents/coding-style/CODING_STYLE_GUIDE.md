# Coding Style Guide

This guide defines the project's coding-style rules for naming, types, table shape, variable layout, module layout, React API usage, and boolean logic.

---

## Naming Conventions

- Use `PascalCase` for module exports, service names, classes, public methods, and table fields.
- Use `camelCase` for local variables and function parameters.
- Use `SCREAMING_SNAKE_CASE` for module-level constants.
- Use `_PascalCase` for private or internal functions and methods.
- Use lowercase `.new` for constructor functions.
- Use `T` for concrete type definitions and `I` for interface or abstract type definitions.

```lua
local InventoryService = {}

function InventoryService:AddItem(itemId, quantity) end

local isValid = true
local MAX_NAME_LENGTH = 20

function InventoryService:_ValidateStack(quantity) end

function CharacterValidator.new() end

export type TItemData = { Id: string, Quantity: number, Rarity: string }
export type IItemValidator = { Validate: (self, itemId: string) -> (boolean, string?) }
```

---

## Type Annotations

- Use `--!strict` at the top of every file.
- Type all function signatures.

```lua
--!strict

function InventoryValidator:ValidateItem(itemId: string, quantity: number): (boolean, { string })
    local errors = {}
    -- implementation...
    return #errors == 0, errors
end

export type TInventoryData = {
    UserId: number,
    Items: { [string]: TItemSlot },
    Capacity: number,
}

export type TItemSlot = {
    ItemId: string,
    Quantity: number,
    Rarity: string,
}
```

---

## Table Conventions

- Use `PascalCase` for all table field keys.
- Keep table fields in `PascalCase` even when the table is local or a config payload.
- Separate type exports from implementation. Type exports live in `Types/` folders.
- Freeze configuration tables. See [IMMUTABILITY.md](IMMUTABILITY.md).

### Metatable Inheritance

- Class tables own their own `__index` field (`MyClass.__index = MyClass`).
- When a class inherits from a base class, set the subclass metatable directly to the base class: `setmetatable(SubClass, BaseClass)`.
- Do not use an inline wrapper metatable such as `setmetatable(SubClass, { __index = BaseClass })`.
- Instance construction continues to point at the concrete class table: `setmetatable({}, MyClass)`.

```lua
local BaseSyncClient = {}
BaseSyncClient.__index = BaseSyncClient

local MySyncClient = {}
MySyncClient.__index = MySyncClient
setmetatable(MySyncClient, BaseSyncClient)

function MySyncClient.new()
    local self = BaseSyncClient.new(...)
    return setmetatable(self, MySyncClient)
end
```

```lua
return table.freeze({
    ItemA = { Name = "Wood", MaxStack = 64, Rarity = "common" },
    ItemB = { Name = "Stone", MaxStack = 64, Rarity = "common" },
})

export type TItemConfig = {
    Name: string,
    MaxStack: number,
    Rarity: string,
}
```

---

## Variable Structure

- Group locals by purpose in this order when a file needs multiple sections:
  - services
  - modules
  - assets
  - settings or constants
  - variables or state
  - auxiliary helpers
  - main or entry functions
- Keep each group visually separated with a short comment header when the file has more than one group.
- Use the simplest name that still communicates intent.
- Avoid generic names like `Table`, `Name`, `Module`, or `Temp` when the variable holds domain-specific data.
- Prefer `Temporary` or `Pending` only when the value is actually short-lived and the context makes that obvious.
- Keep one variable per line when the value is important or reused. Compress only obvious one-off pairs when readability stays high.

```lua
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local InventoryModule = require(ReplicatedStorage.Shared.Inventory)
local ItemModule = require(ReplicatedStorage.Shared.Item)

-- Assets
local Effect = ReplicatedStorage.Assets:WaitForChild("Effect")
local Shockwave = ReplicatedStorage.Assets:WaitForChild("Shockwave")

-- Settings
local PART_SPAWNING_SPEED = 100
local PART_SIZE = 1
local WIND_SPEED = 20

-- Variables
local playerName = "Steve"
local currentItemName = "Sword"
local spawnQueue = {}

-- Auxiliary
local function resetPlayer()
    ...
end

local function convertToModel()
    return ...
end

-- Main
local function fireballHandler()
    ...
end
```

---

## File Structure Convention

Every module follows this order:

1. `--!strict`
2. `require` statements
3. Module-level constants (`SCREAMING_SNAKE_CASE`)
4. Module table declaration
5. Constructor (`.new`)
6. Public methods
7. Private helper functions (`_PascalCase`)
8. `return` statement

```lua
--!strict

local Errors = require(script.Parent.Errors)

local MAX_QUANTITY = 9999

local InventoryValidator = {}
InventoryValidator.__index = InventoryValidator

function InventoryValidator.new()
    local self = setmetatable({}, InventoryValidator)
    return self
end

function InventoryValidator:Validate(itemId: string, quantity: number): (boolean, { string })
    local errors = {}
    if not _IsValidItemId(itemId) then
        table.insert(errors, Errors.INVALID_ITEM_ID)
    end
    if quantity <= 0 or quantity > MAX_QUANTITY then
        table.insert(errors, Errors.INVALID_QUANTITY)
    end
    return #errors == 0, errors
end

local function _IsValidItemId(id: string): boolean
    return type(id) == "string" and #id > 0
end

return InventoryValidator
```

---

## React API Style

- Prefer direct `React.*` hook usage in modules (`React.useEffect`, `React.useMemo`, etc.).
- Local aliases are allowed for readability (`local useEffect = React.useEffect`), but use one style consistently within a file.
- Avoid mixing aliased and direct forms for the same hook in the same module.

---

## Logic Style

- Prefer plain truthiness checks for boolean values.
- Use `if Running then` and `if not Running then` instead of `== true` or `== false`.
- Use explicit `nil` comparisons only when the distinction from `false` or empty values matters.
- Use parentheses to group boolean logic when more than one operator appears in the condition.
- Use parentheses to make precedence explicit when combining `and`, `or`, and `not`.
- Keep single-condition checks simple. Do not add parentheses where they do not improve clarity.

```lua
-- Good
if Running then
end

if not Running then
end

if Existence == nil then
end

if (isValid and hasPermission) or isAdmin then
end

-- Bad
if Running == true then
end

if Running == false then
end

if isValid and hasPermission or isAdmin then
end
```

---

## Related Style Docs

- [READABILITY.md](READABILITY.md)
- [IMMUTABILITY.md](IMMUTABILITY.md)
- [LUAU_TYPES.md](LUAU_TYPES.md)
- [MOONWAVE.md](MOONWAVE.md)
