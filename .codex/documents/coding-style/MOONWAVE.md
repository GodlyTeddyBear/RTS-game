# Moonwave Doc Comments

Moonwave is the Roblox community standard for generating documentation from source comments.
luau-lsp also reads Moonwave-style comments and displays them as hover docs in VS Code.

---

## Comment Styles

Two styles are equivalent — pick one per file and stay consistent:

```lua
-- Multi-line block (preferred for longer descriptions)
--[=[
    Description here.
    @param name type -- desc
    @return type -- desc
]=]

-- Single-line triple-dash (concise one-liners or short descriptions)
--- Description here.
--- @param name type -- desc
--- @return type -- desc
```

**Never use `--[[...]]` or `--` for doc comments** — Moonwave ignores both entirely.

| Syntax | Moonwave sees it? |
|--------|-------------------|
| `--[=[...]=]` | Yes |
| `--- ...` | Yes |
| `--[[...]]` | No — plain block comment |
| `-- ...` | No — plain inline comment |

---

## Required Structure

Every Moonwave doc file must have exactly one `@class` declaration. Every other item
(functions, props, types) must include `@within <ClassName>` or Moonwave won't attach it.

```lua
--[=[
    @class Result
    Structured error handling with exception propagation.
]=]
local Result = {}

--[=[
    Wraps a success value into a Result.
    @within Result
    @param value T -- The success payload
    @return Ok<T>
]=]
function Result.Ok(value) ... end
```

---

## All Supported Tags

### Doc-type tags (one required per block)

| Tag | Syntax | Purpose |
|-----|--------|---------|
| `@class` | `@class Name` | Declares a class |
| `@prop` | `@prop name type` | Property on a class |
| `@type` | `@type name type` | Type alias |
| `@interface` | `@interface Name` | Table shape/structure |
| `@function` | `@function name` | Function not auto-detected by Moonwave |
| `@method` | `@method name` | Colon-method not auto-detected |

### Scoping

| Tag | Syntax | Notes |
|-----|--------|-------|
| `@within` | `@within ClassName` | **Required** on all non-class items |

### Function tags

| Tag | Syntax | Notes |
|-----|--------|-------|
| `@param` | `@param name type -- desc` | Repeatable for multiple params |
| `@return` | `@return type -- desc` | Repeatable for multiple return values |
| `@error` | `@error type -- desc` | Errors the function may throw |
| `@yields` | `@yields` | Marks function as yielding |

### Metadata

| Tag | Syntax | Notes |
|-----|--------|-------|
| `@since` | `@since version` | Version when introduced |
| `@deprecated` | `@deprecated version -- desc` | Marks obsolete |
| `@tag` | `@tag label` | Visual category label |
| `@readonly` | `@readonly` | Props only — not writable |
| `@private` | `@private` | Hidden from docs output |
| `@ignore` | `@ignore` | Fully excluded from output |
| `@server` | `@server` | Server-only |
| `@client` | `@client` | Client-only |

---

## Interfaces

Use dot-notation for fields inside `@interface` blocks:

```lua
--[=[
    @interface CurrencyData
    @within CurrencyService
    .Coins number -- Current coin count
    .Gems number -- Current gem count
    .LastUpdated number -- Unix timestamp
]=]
```

---

## Multiple Return Values

```lua
--[=[
    @return number -- Primary result
    @return string -- Human-readable description
    @return boolean -- Whether the result is valid
]=]
```

---

## Type Aliases

```lua
--[=[
    @type Coins number
    @within CurrencyService
]=]
```

---

## Examples

### Class with a property

```lua
--[=[
    @class CurrencyService
    Manages player currency.
    @server
]=]
local CurrencyService = {}

--[=[
    @prop Balance number
    @within CurrencyService
    @readonly
    The player's current coin balance.
]=]
```

### Documented function

```lua
--[=[
    Awards coins to a player.
    @within CurrencyService
    @param player Player -- The player to award
    @param amount number -- How many coins to award
    @return boolean -- Whether the award succeeded
    @error string -- Thrown if amount is negative
]=]
function CurrencyService:AwardCoins(player: Player, amount: number): boolean
```

### Yielding function

```lua
--[=[
    Loads data from the datastore. Yields until complete.
    @within CurrencyService
    @param player Player
    @return CurrencyData
    @yields
]=]
```

### Deprecated item

```lua
--[=[
    @deprecated 2.0.0 -- Use AwardCoins instead
    @within CurrencyService
]=]
function CurrencyService:GiveCoins(player, amount)
```

---

## Notes

- **Auto-detection**: Moonwave auto-detects functions placed directly below a doc comment.
  Use `@function` / `@method` only for dynamically assigned or generated functions.
- **Type inference**: Luau type annotations (`: number`, `: Player`) are read automatically.
  Add `@param` only when you need a description, not to repeat the type.
- **Descriptions** support Markdown and inline backtick code.
