--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type AbilitySlotDef = CommanderTypes.AbilitySlotDef
type SlotKey = CommanderTypes.SlotKey

--[=[
	@interface AbilitySlotRecord
	@within AbilitySlot
	.Key SlotKey -- Stable commander slot identifier.
	.DisplayName string -- Player-facing slot name.
	.EnergyCost number -- Energy cost required to activate the slot.
	.CooldownDuration number -- Cooldown duration in seconds.
	.Metadata { [string]: any }? -- Optional slot-specific tuning values.
]=]
export type AbilitySlotRecord = {
	Key: SlotKey,
	DisplayName: string,
	EnergyCost: number,
	CooldownDuration: number,
	Metadata: { [string]: any }?,
}

--[=[
	@class AbilitySlot
	Wraps a commander slot definition in an immutable domain record.
	@server
]=]
local AbilitySlot = {}

--[=[
	Builds an immutable ability slot record from shared config data.
	@within AbilitySlot
	@param def AbilitySlotDef -- The source slot definition.
	@return AbilitySlotRecord -- The frozen slot record.
]=]
function AbilitySlot.new(def: AbilitySlotDef): AbilitySlotRecord
	return table.freeze({
		Key = def.key,
		DisplayName = def.displayName,
		EnergyCost = def.energyCost,
		CooldownDuration = def.cooldownDuration,
		Metadata = def.metadata,
	})
end

return table.freeze(AbilitySlot)
