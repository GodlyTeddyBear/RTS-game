--!strict

--[=[
	@class GuildSpecs
	Composable eligibility rules (specifications) for guild operations.
	Each spec is a pure predicate: given a candidate, return true (Ok) or false (Err).
	Specs never fetch state — they receive it via the candidate.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@interface TGuildHireCandidate
	@within GuildSpecs
	.AdventurerTypeValid boolean -- Adventurer type key exists in AdventurerConfig
	.RosterNotFull boolean -- Roster is below MAX_ROSTER_SIZE (defensive: true when type invalid)
	.SufficientGold boolean -- Player gold >= hire cost (defensive: true when type invalid)
]=]
export type TGuildHireCandidate = {
	AdventurerTypeValid: boolean,
	RosterNotFull: boolean,
	SufficientGold: boolean,
}

--[=[
	@interface TEquipItemCandidate
	@within GuildSpecs
	.AdventurerExists boolean -- Adventurer ID is present in the roster
	.SlotTypeValid boolean -- Slot is Weapon, Armor, or Accessory (defensive: true when adventurer missing)
	.InventorySlotOccupied boolean -- Inventory slot contains an item (defensive: true when adventurer missing)
	.ItemEquippable boolean -- Item category maps to slot type (defensive: true when slot empty/invalid)
]=]
export type TEquipItemCandidate = {
	AdventurerExists: boolean,
	SlotTypeValid: boolean,
	InventorySlotOccupied: boolean,
	ItemEquippable: boolean,
}

--[=[
	@interface TUnequipItemCandidate
	@within GuildSpecs
	.AdventurerExists boolean -- Adventurer ID is present in the roster
	.UnequipSlotTypeValid boolean -- Slot is Weapon, Armor, or Accessory (defensive: true when adventurer missing)
	.SlotNotEmpty boolean -- Equipment slot is currently occupied (defensive: true when slot type invalid)
]=]
export type TUnequipItemCandidate = {
	AdventurerExists: boolean,
	UnequipSlotTypeValid: boolean,
	SlotNotEmpty: boolean,
}

-- Individual specs — Hire

local AdventurerTypeValid = Spec.new("InvalidAdventurerType", Errors.INVALID_ADVENTURER_TYPE,
	function(ctx: TGuildHireCandidate) return ctx.AdventurerTypeValid end
)

local RosterNotFull = Spec.new("RosterFull", Errors.ROSTER_FULL,
	function(ctx: TGuildHireCandidate) return ctx.RosterNotFull end
)

local SufficientGold = Spec.new("InsufficientGold", Errors.INSUFFICIENT_GOLD,
	function(ctx: TGuildHireCandidate) return ctx.SufficientGold end
)

-- Individual specs — Equip

local AdventurerExists = Spec.new("AdventurerNotFound", Errors.ADVENTURER_NOT_FOUND,
	function(ctx: TEquipItemCandidate) return ctx.AdventurerExists end
)

local SlotTypeValid = Spec.new("InvalidSlotType", Errors.INVALID_SLOT_TYPE,
	function(ctx: TEquipItemCandidate) return ctx.SlotTypeValid end
)

local InventorySlotOccupied = Spec.new("ItemNotInInventory", Errors.ITEM_NOT_IN_INVENTORY,
	function(ctx: TEquipItemCandidate) return ctx.InventorySlotOccupied end
)

local ItemEquippable = Spec.new("ItemNotEquippable", Errors.ITEM_NOT_EQUIPPABLE,
	function(ctx: TEquipItemCandidate) return ctx.ItemEquippable end
)

-- Individual specs — Unequip

local UnequipAdventurerExists = Spec.new("AdventurerNotFound", Errors.ADVENTURER_NOT_FOUND,
	function(ctx: TUnequipItemCandidate) return ctx.AdventurerExists end
)

local UnequipSlotTypeValid = Spec.new("InvalidSlotType", Errors.INVALID_SLOT_TYPE,
	function(ctx: TUnequipItemCandidate) return ctx.UnequipSlotTypeValid end
)

local SlotNotEmpty = Spec.new("SlotAlreadyEmpty", Errors.SLOT_ALREADY_EMPTY,
	function(ctx: TUnequipItemCandidate) return ctx.SlotNotEmpty end
)

--[=[
	@prop CanHireAdventurer Spec
	@within GuildSpecs
	Composite spec: valid type AND (roster not full AND sufficient gold).
	Short-circuits on invalid type, so only root error is reported.
]=]

--[=[
	@prop CanEquipItem Spec
	@within GuildSpecs
	Composite spec: adventurer exists AND (valid slot AND slot occupied AND item equippable).
	Short-circuits on missing adventurer, so only root error is reported.
]=]

--[=[
	@prop CanUnequipItem Spec
	@within GuildSpecs
	Composite spec: adventurer exists AND (valid slot AND slot not empty).
	Short-circuits on missing adventurer, so only root error is reported.
]=]
return table.freeze({
	CanHireAdventurer = AdventurerTypeValid:And(Spec.All({ RosterNotFull, SufficientGold })),
	CanEquipItem      = AdventurerExists:And(Spec.All({ SlotTypeValid, InventorySlotOccupied, ItemEquippable })),
	CanUnequipItem    = UnequipAdventurerExists:And(Spec.All({ UnequipSlotTypeValid, SlotNotEmpty })),
})
