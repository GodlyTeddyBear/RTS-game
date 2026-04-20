--!strict

--[=[
	@class CombatEvents
	Event registry for the Combat bounded context.
	@server
]=]

--[=[
	@prop WaveComplete string
	@within CombatEvents
	Fired when a wave is completed. Emitted with: `(dungeonInstanceId: number)`
]=]

--[=[
	@prop AllAdventurersDead string
	@within CombatEvents
	Fired when all party members are defeated. Emitted with: `(dungeonInstanceId: number)`
]=]

--[=[
	@prop CombatEnded string
	@within CombatEvents
	Fired when combat concludes (victory or defeat). Emitted with: `(dungeonInstanceId: number, result: string, rewards: table)`
]=]

--[=[
	@prop WaveTransitionStarted string
	@within CombatEvents
	Fired when transitioning to the next wave. Emitted with: `(dungeonInstanceId: number, nextWaveNumber: number)`
]=]

--[=[
	@prop WaveTransitionComplete string
	@within CombatEvents
	Fired when wave transition is finished. Emitted with: `(dungeonInstanceId: number, waveNumber: number)`
]=]

--[=[
	@prop NPCDamaged string
	@within CombatEvents
	Fired when an enemy takes damage. Emitted with: `(dungeonInstanceId: number, npcId: string, damageAmount: number, remainingHealth: number)`
]=]

--[=[
	@prop NPCDied string
	@within CombatEvents
	Fired when an enemy is defeated. Emitted with: `(dungeonInstanceId: number, npcId: string, defeatedBy: string, killedByType: string)`
]=]

local events = table.freeze({
	WaveComplete = "Combat.WaveComplete",
	AllAdventurersDead = "Combat.AllAdventurersDead",
	CombatEnded = "Combat.CombatEnded",
	WaveTransitionStarted = "Combat.WaveTransitionStarted",
	WaveTransitionComplete = "Combat.WaveTransitionComplete",
	NPCDamaged = "Combat.NPCDamaged",
	NPCDied = "Combat.NPCDied",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.WaveComplete] = { "number" },
	[events.AllAdventurersDead] = { "number" },
	[events.CombatEnded] = { "number", "string", "table" },
	[events.WaveTransitionStarted] = { "number", "number" },
	[events.WaveTransitionComplete] = { "number", "number" },
	[events.NPCDamaged] = { "number", "string", "number", "number" },
	[events.NPCDied] = { "number", "string", "string", "string" },
}

return { events = events, schemas = schemas }
