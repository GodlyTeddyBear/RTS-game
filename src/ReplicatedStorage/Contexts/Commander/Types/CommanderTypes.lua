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
	.key SlotKey -- Stable slot identifier.
	.displayName string -- Player-facing slot name.
	.energyCost number -- Energy cost to activate the slot.
	.cooldownDuration number -- Cooldown duration in seconds.
	.metadata { [string]: any }? -- Slot-specific tuning values.
		Current v1 defaults encoded in CommanderConfig metadata:
		- Mobility: `maxRange`, `lockedWhileOverchargeChanneling`
		- SummonA: `summonCount`, `lifetime`, `targetingRule = "NearestEnemy"`
		- SummonB: `lifetime`, `stationary`, `pathingMode = "PassThrough"`
		- Control: `radius`, `knockbackStuds`, `slowDuration`
		- Ultimate: `channelTime`, `interruptibleByDamage`, `movementLockedDuringChannel`,
		  `radius`, `stunDuration`, `structureAttackSpeedMultiplier`, `buffDuration`
]=]
export type AbilitySlotDef = {
	key: SlotKey,
	displayName: string,
	energyCost: number,
	cooldownDuration: number,
	metadata: { [string]: any }?,
}

--[=[
	@interface CooldownEntry
	@within CommanderTypes
	.startedAt number -- Clock time when the cooldown began.
	.duration number -- Cooldown duration in seconds.
]=]
export type CooldownEntry = {
	startedAt: number,
	duration: number,
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
	.hp number -- Current commander HP.
	.maxHp number -- Maximum commander HP.
	.cooldowns CooldownState -- Per-slot cooldown entries.
]=]
export type CommanderState = {
	hp: number,
	maxHp: number,
	cooldowns: CooldownState,
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
