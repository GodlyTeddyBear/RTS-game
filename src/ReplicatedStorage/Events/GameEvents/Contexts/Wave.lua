--!strict

--[=[
	@class Wave
	Defines the wave combat GameEvents used by the Wave context.
	@server
	@client
]=]
local Wave = {}

--[=[
	@prop events table
	@within Wave
	Wave event name constants.
]=]
local events = table.freeze({
	SpawnEnemy = "Wave.SpawnEnemy",
	EnemyDied = "Wave.EnemyDied",
})

--[=[
	@prop schemas table
	@within Wave
	Validation schemas for each Wave event.
]=]
local schemas: { [string]: { string } } = {
	[events.SpawnEnemy] = { "string", "CFrame", "number" },
	[events.EnemyDied] = { "string", "number", "CFrame" },
}

Wave.events = events
Wave.schemas = schemas

return Wave
