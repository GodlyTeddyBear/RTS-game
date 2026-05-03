--!strict

--[=[
	@class CommanderTypes
	Defines the shared commander state and slot shapes used by server and client code.
	@server
	@client
]=]
local CommanderTypes = {}

--[=[
	@type SlotKey "Mobility" | "SummonA" | "SummonB" | "Control" | "Ultimate"
	@within CommanderTypes
	Names a commander ability slot.
]=]
export type SlotKey = "Mobility" | "SummonA" | "SummonB" | "Control" | "Ultimate"

--[=[
	@interface AbilitySlotDef
	@within CommanderTypes
	.Key SlotKey -- Stable slot identifier.
	.DisplayName string -- Player-facing slot name.
	.EnergyCost number -- Energy cost to activate the slot.
	.CooldownDuration number -- Cooldown duration in seconds.
	.Metadata { [string]: any }? -- Slot-specific tuning values.
		Current v1 defaults encoded in CommanderConfig metadata:
		- Mobility: `MaxRange`, `LockedWhileOverchargeChanneling`
		- SummonA: `SummonCount`, `Lifetime`, `TargetingRule = "NearestEnemy"`
		- SummonB: `Lifetime`, `Stationary`, `PathingMode = "PassThrough"`
		- Control: `Radius`, `KnockbackStuds`, `SlowDuration`
		- Ultimate: `ChannelTime`, `InterruptibleByDamage`, `MovementLockedDuringChannel`,
		  `Radius`, `StunDuration`, `StructureAttackSpeedMultiplier`, `BuffDuration`
]=]
export type AbilitySlotDef = {
	Key: SlotKey,
	DisplayName: string,
	EnergyCost: number,
	CooldownDuration: number,
	Metadata: { [string]: any }?,
}

--[=[
	@interface CooldownEntry
	@within CommanderTypes
	.StartedAt number -- Clock time when the cooldown began.
	.Duration number -- Cooldown duration in seconds.
]=]
export type CooldownEntry = {
	StartedAt: number,
	Duration: number,
}

--[=[
	@type CooldownState { [SlotKey]: CooldownEntry? }
	@within CommanderTypes
	Maps ability slot keys to their current cooldown entry.
]=]
export type CooldownState = {
	[SlotKey]: CooldownEntry?,
}

--[=[
	@interface CommanderState
	@within CommanderTypes
	.Hp number -- Current commander HP.
	.MaxHp number -- Maximum commander HP.
	.Cooldowns CooldownState -- Per-slot cooldown entries.
]=]
export type CommanderState = {
	Hp: number,
	MaxHp: number,
	Cooldowns: CooldownState,
}

--[=[
	@type CommanderAtomState { [number]: CommanderState }
	@within CommanderTypes
	Server-side per-player commander atom keyed by `userId`.
]=]
export type CommanderAtomState = {
	[number]: CommanderState,
}

--[=[
	@type CommanderClientState CommanderState?
	@within CommanderTypes
	Client-side player-scoped commander snapshot received from sync payloads.
]=]
export type CommanderClientState = CommanderState?

return table.freeze(CommanderTypes)
