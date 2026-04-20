# Coding Style

## Naming Conventions

### PascalCase
Module exports, service names, classes, public methods, table fields.

```lua
local InventoryService = {}
function InventoryService:AddItem(itemId, quantity) end
local config = { Name = "Wood", MaxStack = 64 }
```

### camelCase
Local variables and function parameters.

```lua
local isValid = true
local characterCount = 0
local function processItem(itemId, quantity) end
```

### SCREAMING_SNAKE_CASE
Module-level constants.

```lua
local MAX_NAME_LENGTH = 20
local DEFAULT_HEALTH = 100
local INVALID_ENTITY_ID = -1
```

### _PascalCase
Private/internal functions and methods. The underscore prefix signals "not part of the public API."

```lua
function InventoryService:_ValidateStack(quantity) end
local function _IsValidItemId(id) end
```

### `.new`
Constructor functions — always lowercase `.new`.

```lua
function CharacterValidator.new() end
function UserId.new(value) end
```

### `T` / `I` prefix
Type definitions: `T` for concrete types, `I` for interface/abstract types.

```lua
export type TItemData = { Id: string, Quantity: number, Rarity: string }
export type IItemValidator = { Validate: (self, itemId: string) -> (boolean, string?) }
```

---

## Type Annotations

Use `--!strict` at the top of every file. Type all function signatures.

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

- Use **PascalCase** for all table field keys
- Separate type exports from implementation — types live in `Types/` folders
- Freeze configuration tables (see [IMMUTABILITY.md](IMMUTABILITY.md))

```lua
-- Config table
return table.freeze({
    ItemA = { Name = "Wood", MaxStack = 64, Rarity = "common" },
    ItemB = { Name = "Stone", MaxStack = 64, Rarity = "common" },
})

-- Type definition (separate file)
export type TItemConfig = {
    Name: string,
    MaxStack: number,
    Rarity: string,
}
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

## React API Style (Frontend)

- Prefer direct `React.*` hook usage in modules (`React.useEffect`, `React.useMemo`, etc.).
- Local aliases are allowed for readability (`local useEffect = React.useEffect`), but use one style consistently within a file.
- Avoid mixing aliased and direct forms for the same hook in the same module.
