# Instance Reveal Rules


---
## Purpose

Instance Reveal is the mechanism for replicating ECS entity state to the client via Roblox Instance **Attributes** and **CollectionService Tags**. It is a controlled reveal channel — the server decides when an instance becomes discoverable by the client.

This is distinct from Charm-sync, which handles structured player data. Use Instance Reveal when the client needs to discover or query world instances (NPCs, resources, structures, targets) by type, identity, or membership.

---

## Core Rules

- Only the server stamps attributes and tags onto instances — never the client
- Stamping is deferred and controlled — instances are not stamped at spawn unless they should be immediately visible
- `TRevealState` is the contract between builder and applier — build the state separately from applying it
- Attributes carry scalar values the client reads directly off the instance
- CollectionService tags express binary membership the client queries by
- Removal is always explicit — use `ClearAttributes` in `TRevealState`, never leave stale attributes

---

## When to Use Instance Reveal vs Charm-sync

| Concern | Use |
|---------|-----|
| Client discovers world instances by type or id | Instance Reveal |
| Client reads structured player data (inventory, stats, currency) | Charm-sync |
| Client needs to query a set of instances (e.g. "all ore nodes") | Instance Reveal (CollectionService tag) |
| Client needs a single scalar value on a known instance | Instance Reveal (Attribute) |
| Data changes frequently per-frame | Charm-sync or physics replication — not Reveal |

---

## TRevealState Contract

`TRevealState` is the canonical type for all reveal and un-reveal operations.

```lua
export type TRevealState = {
    Attributes: { [string]: TAttributeValue }?,  -- attributes to set
    ClearAttributes: { string }?,                -- attribute keys to remove
    Tags: { [string]: boolean }?,               -- true = add tag, false = remove tag
}
```

- **Build** the state with a builder (e.g. `TargetRevealBuilder.Build`)
- **Apply** the state with an applier (e.g. `ECSRevealApplier.Apply`)
- Never construct `TRevealState` inline at the call site — always go through a builder

---

## Tag Naming Convention

Tags follow a hierarchical `"Prefix:Type"` and `"Prefix:Type:SourceId"` structure.

```text
"Target:Ore"           -- type-level: all ore targets
"Target:Ore:rock_1"    -- type-and-source: specific ore definition
```

Rules:
- Tag prefix is declared once in the schema (e.g. `TargetSchema.TAG_PREFIX = "Target:"`)
- Type-level tag is always stamped — enables querying all instances of a type
- Type-and-source tag is stamped when the source identity matters — enables querying a specific definition
- Use `TargetSchema.IsTargetTag(tag)` to identify tags belonging to this system — never hardcode the prefix at the call site
- Tag names are `PascalCase` segments separated by `":"`

---

## Attribute Naming Convention

- Attribute names are `PascalCase` strings declared as constants in the schema (e.g. `ATTR_TARGET_ID`, `ATTR_TARGET_TYPE`)
- Never hardcode an attribute name string outside the schema module
- Attributes carry the minimum data the client needs to identify and classify the instance
- Do not put gameplay state (health, cooldowns, quantities) in attributes — that belongs in Charm-sync or ECS

---

## TargetId Convention

`TargetId` is a scoped string that uniquely identifies a target instance:

```text
"zone1:Ore:rock_1"   -- scopeId:targetType:sourceId
```

Built with `TargetSchema.MakeScopedTargetId(scopeId, targetType, sourceId)`. Never construct this string manually.

---

## Client Discovery

The client discovers revealed instances through `TargetIndexService`, which subscribes to CollectionService tags and indexes instances by their attributes. Controllers expose the index via typed query methods.

```lua
-- Find a specific instance by type + id
local instance = TargetingController:FindFirstByTypeAndId("Ore", "zone1:Ore:rock_1")

-- Find all instances of a type
local allOre = TargetingController:FindAllByTag("Target:Ore")

-- Find all instances across a system by prefix
local allTargets = TargetingController:FindAllByTagPrefix("Target:")
```

The client never reads ECS components or queries the ECS world — it reads only Attributes and Tags from the index.

---

## Pipeline

```text
ECS [AUTHORITATIVE] component
    → server sync system decides to reveal
    → TargetRevealBuilder.Build(options) → TRevealState
    → ECSRevealApplier.Apply(instance, revealState)
    → CollectionService tag + Instance Attributes set on server
    → Roblox replicates to client automatically
    → TargetIndexService indexes the instance
    → TargetingController exposes it to client systems
```

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

---

## Prohibitions

- Do not violate the required rules defined in this document's Core Rules and contract sections.

---

## Failure Signals

- Implementation behavior contradicts one or more required rules in this contract.

---

## Checklist

- [ ] All required rules in this contract are satisfied.

