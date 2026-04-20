# Luau Type System — Patterns and Problem Scenarios

This document covers Luau's type checking system as it applies to this project: common issues, how to diagnose them, the solutions that work in Roblox's old type solver (`--!strict`), and type functions available in the new solver.

---

## Type Checking Modes

```lua
--!nocheck    -- No type checking
--!nonstrict  -- Default; unannotated values are `any`
--!strict     -- Infers and checks everything; use this everywhere
```

---

## Basic Annotation Syntax

```lua
local count: number = 0
local name: string? = nil          -- optional: string | nil

local function add(x: number, y: number): number
    return x + y
end

type UserId = number
export type PlayerData = { id: UserId, name: string }
```

---

## Generics

```lua
type Box<T> = { value: T }
type List<T> = { T }

local function identity<T>(value: T): T
    return value
end
```

Limitations in the old solver:
- No type parameter constraints (`extends`)
- No default type parameters (`T = string`)
- Generic methods on structural table types are partially supported (see below)

---

## OOP / Metatable Typing

The canonical pattern:

```lua
type MyClass = typeof(setmetatable(
    {} :: { value: number },
    {} :: { __index: {
        getValue: (MyClass) -> number,
    }}
))
```

`self` is not auto-unified across method definitions — annotate it explicitly on each method or use the `typeof(setmetatable(...))` pattern.

---

## Problem: Generic Chaining Changes the Type

### Scenario

You have a generic type like `Specification<T>` with a method that returns another instance of the same type. After chaining, the type checker sees a *different* type parameter and errors.

```lua
-- specA: Specification<AType>
-- specB: Specification<BType>
local combined = specA:And(specB)
-- Error: Specification<AType> is not Specification<BType>
```

### Option 1 — Widen to `any` (simplest, loses type safety)

```lua
And: (self: Specification<T>, other: Specification<any>) -> Specification<any>,
```

The chain compiles cleanly. The tradeoff is that the result is `Specification<any>` — calling `:IsSatisfiedBy()` on it accepts anything.

Use when: the composed specs always share the same candidate type in practice, and you just need the checker to stop erroring.

### Option 2 — Generic method parameter (preserves the chain type)

```lua
And: <B>(self: Specification<T>, other: Specification<B>) -> Specification<B>,
```

After chaining, the result is `Specification<B>` — typed to the *last* spec passed. Each subsequent chain link takes the type of whatever is passed to it.

- `A` is not preserved — the chain reflects the current link's type, not the origin
- This is intentional: the result type is what matters for calling `:IsSatisfiedBy()`
- Partially supported in the old solver; works for straightforward chains

Use when: you want the chained result to carry a meaningful type rather than `any`.

### Which to use

If all composed specs share the same candidate type (the intended usage), Option 2 is correct — `B` will equal `T` throughout the chain and everything stays consistent. If you need to compose specs with genuinely different candidate types, Option 1 is the only safe choice.

---

## Problem: Recursive Type Warning

### Scenario

A type references itself in its own method signatures:

```lua
export type Specification<T> = {
    And: <B>(self: Specification<T>, other: Specification<B>) -> Specification<B>,
}
```

The solver emits a "recursive type" warning.

### What it means

The solver detected a cycle and warns rather than infinitely expanding the type. This is **expected and harmless** for composable types that must reference themselves. The code runs correctly; the checker may weaken inference to `any` at the recursive reference point in complex cases.

### Resolution

No action needed. The warning is unavoidable for self-referential composable types. As long as call sites type-check correctly, ignore it.

---

## Problem: `any` is Viral

Once a value is typed as `any`, all operations on it produce `any`, suppressing all downstream errors silently.

```lua
local x: any = getValue()
local y = x.foo        -- y is any
local z = y + 1        -- z is any, no error even if foo doesn't exist
```

Avoid `any` except at intentional escape hatches (metatable casts, internal constructors). Use `:: any` casts locally and as narrowly as possible.

---

## Problem: `self` Not Unified Across Methods

```lua
function MyClass:doThing()
    self.value = 1  -- self inferred independently here
end

function MyClass:doOther()
    self.value = "hi"  -- self inferred independently here — no conflict caught
end
```

The checker infers `self` separately per method. It won't catch cross-method type inconsistencies. Use the `typeof(setmetatable(...))` pattern to define the class type once and annotate `self` explicitly.

---

## Problem: Dynamic `require` Paths Break Type Checking

```lua
local module = require(path .. "/MyModule")  -- path is any, module is any
```

The checker cannot resolve dynamic paths. Always use static `require` paths so the checker can type the returned module.

---

## Type Casting with `::`

Static only — no runtime cost or effect:

```lua
local s = (someAny :: string)      -- override inferred type
local val = x :: any :: string     -- double-cast for hard escapes
```

**Gotcha:** Casting a multi-return expression drops all values after the first.

---

## Roblox-Specific Notes

- `Instance.new("Part")` returns `Part`, not `Instance`
- `game:GetService("ReplicatedStorage")` returns `ReplicatedStorage`
- `inst:IsA("Part")` narrows `inst` to `Part` inside the branch
- `unknown` is not recognized by the old solver — use `any` instead
- The new type solver (generally released November 2025) handles generic methods and recursive types better
- Strict mode users can opt in via `UseNewLuauTypeSolver` workspace property; old solver remains available through 2026

---

## Type Functions (New Type Solver)

Type functions run **at analysis time**, not at runtime. They take type arguments and return a new type. Zero runtime cost or presence.

> **Requires the new type solver.** Available in Roblox Studio as of November 2025 general release. Strict mode users must opt in via `UseNewLuauTypeSolver`.

### Syntax

```lua
-- Declaration: parentheses (runs as Luau code during analysis)
type function f(argType)
    -- body using types library
    return argType
end

-- Call: angle brackets (type arguments)
type MyType = f<string>
```

### Available Environment

Inside a type function you have access to: `assert`, `error`, `print`, `next`, `ipairs`, `pairs`, `select`, `unpack`, `getmetatable`, `setmetatable`, `rawget`, `rawset`, `rawlen`, `rawequal`, `tonumber`, `tostring`, `type`, `typeof`, and the libraries `math`, `table`, `string`, `bit32`, `utf8`, `buffer`, plus the `types` library.

No access to runtime functions or variables from the enclosing script.

---

### `types` Library — Constructors

```lua
types.unknown          -- the unknown type
types.never            -- the never type
types.any              -- the any type
types.boolean          -- the boolean type
types.number           -- the number type
types.string           -- the string type

types.singleton(value)              -- string | boolean | nil singleton type
types.negationof(t)                 -- negation type (not table/function)
types.unionof(t1, t2, ...)          -- union type (2+ args required)
types.intersectionof(t1, t2, ...)   -- intersection type (2+ args required)
types.newtable(props?, indexer?, metatable?)  -- mutable table type
types.newfunction(parameters, returns)        -- mutable function type
types.copy(t)                       -- deep copy of a type
```

---

### `type` Instance — Shared Methods

Every type object has:

```lua
t:is(tag: string) -> boolean   -- check tag
t.tag -> string                 -- read the tag directly
```

Tags: `"nil"`, `"unknown"`, `"never"`, `"any"`, `"boolean"`, `"number"`, `"string"`, `"singleton"`, `"negation"`, `"union"`, `"intersection"`, `"table"`, `"function"`, `"class"`

---

### `type` Instance — Tag-Specific Methods

**Singleton:**
```lua
t:value() -> string | boolean | nil
```

**Negation:**
```lua
t:inner() -> type
```

**Union / Intersection:**
```lua
t:components() -> {type}
```

**Table:**
```lua
-- Properties
t:setproperty(key: type, value: type?)
t:setreadproperty(key: type, value: type?)
t:setwriteproperty(key: type, value: type?)
t:readproperty(key: type) -> type?
t:writeproperty(key: type) -> type?
t:properties() -> {[type]: {read: type?, write: type?}}

-- Indexer
t:setindexer(index: type, result: type)
t:setreadindexer(index: type, result: type)
t:setwriteindexer(index: type, result: type)
t:indexer() -> {index: type, readresult: type, writeresult: type}?
t:readindexer() -> {index: type, result: type}?
t:writeindexer() -> {index: type, result: type}?

-- Metatable
t:setmetatable(arg: type)
t:metatable() -> type?
```

**Function:**
```lua
t:setparameters(head: {type}?, tail: type?)
t:parameters() -> {head: {type}?, tail: type?}
t:setreturns(head: {type}?, tail: type?)
t:returns() -> {head: {type}?, tail: type?}
```

**Class (Roblox instances):**
```lua
t:properties() -> {[type]: {read: type, write: type}}
t:readparent() -> type?
t:writeparent() -> type?
t:metatable() -> type?
t:indexer() -> {index: type, readresult: type, writeresult: type}?
```

---

### Practical Examples

**`keyof` — union of all property name singletons:**
```lua
type function keyof(tbl)
    if not tbl:is("table") then
        error("keyof expects a table type")
    end
    local keys = {}
    for key, _ in tbl:properties() do
        table.insert(keys, key)
    end
    if #keys == 0 then return types.never end
    if #keys == 1 then return keys[1] end
    return types.unionof(table.unpack(keys))
end

type Person = { name: string, age: number }
type PersonKeys = keyof<Person>  -- "name" | "age"
```

**`Partial` — make all fields optional:**
```lua
type function Partial(tbl)
    if not tbl:is("table") then
        error("Partial expects a table type")
    end
    local result = types.newtable()
    for key, prop in tbl:properties() do
        result:setproperty(key, types.unionof(prop.read, types.singleton(nil)))
    end
    return result
end

type PartialPerson = Partial<Person>  -- { name: string?, age: number? }
```

**`rawget` — extract a specific property type:**
```lua
type function rawget(tbl, key)
    if not tbl:is("table") then
        error("first parameter must be a table type")
    end
    for k, v in tbl:properties() do
        if k == key then return v.read end
    end
    error("key not found")
end

type NameType = rawget<Person, "name">  -- string
```

**Filter union components:**
```lua
type function nonNullable(u)
    if not u:is("union") then return u end
    local kept = {}
    for _, component in ipairs(u:components()) do
        if not component:is("nil") then
            table.insert(kept, component)
        end
    end
    if #kept == 0 then return types.never end
    if #kept == 1 then return kept[1] end
    return types.unionof(table.unpack(kept))
end

type Name = string?
type NonNullName = nonNullable<Name>  -- string
```

---

### Limitations

1. **New solver only** — type functions do not work in the old solver.
2. **Single return** — must return exactly one `type`; multiple returns are an error.
3. **No outer scope access** — cannot reference runtime variables or functions from the enclosing script.
4. **No termination guarantee** — infinite loops are possible; the system uses a global analysis timeout.
5. **Dynamically typed internals** — no kind checking inside type functions yet; errors surface at analysis time via `error()`.
6. **No type pack functions yet** — variadic type argument packs are excluded from the current implementation.