--!strict

--[[
	GameEvents - Typed event registry and shared bus for cross-context communication.

	Exports:
		GameEvents.Events  — Grouped, frozen event name constants
		GameEvents.Bus     — The singleton EventBus wired with middleware

	Usage:
		local GameEvents = require(ReplicatedStorage.Events.GameEvents)

		-- Producer:
		GameEvents.Bus:Emit(GameEvents.Events.Worker.WorkerHired, userId, workerId, workerType)

		-- Consumer:
		GameEvents.Bus:On(GameEvents.Events.Worker.WorkerHired, function(userId, workerId, workerType)
			-- handle
		end)

	Adding a new domain:
		1. Create a new file in the appropriate category subfolder:
		   - Contexts/  — events owned by a server bounded context
		   - Dialogue/  — events consumed by the Dialogue context
		   - Misc/      — cross-cutting events (UI, Persistence, etc.)
		2. Require it in the domainModules list below.
]]

--[=[
	@class GameEvents
	Centralized event registry and bus for cross-context application communication.
	@server
]=]

local EventBus = require(script.Parent.EventBus)
local EventMiddleware = require(script.Parent.EventMiddleware)
local EventValidator = require(script.Parent.EventValidator)

local domainModules = {
	-- Context-owned events
	Combat = require(script.Contexts.Combat),
	Building = require(script.Contexts.Building),
	Chapter = require(script.Contexts.Chapter),
	Dungeon = require(script.Contexts.Dungeon),
	Worker = require(script.Contexts.Worker),
	Inventory = require(script.Contexts.Inventory),
	Crafting = require(script.Contexts.Crafting),
	Commission = require(script.Contexts.Commission),
	Equipment = require(script.Contexts.Equipment),
	Quest = require(script.Contexts.Quest),
	Lot = require(script.Contexts.Lot),

	-- Dialogue-driven events
	Guide = require(script.Dialogue.Guide),
	Dialogue = require(script.Dialogue.Flags),

	-- Cross-cutting events
	UI = require(script.Misc.UI),
	Persistence = require(script.Misc.Persistence),
}

-- Merge all domain events into a grouped structure (e.g., Events.Worker.WorkerHired)
local eventsRaw = {}
-- Collect all validation schemas from domains for the validator
local schemasRaw: { [string]: { string } } = {}

for domain, mod in domainModules do
	eventsRaw[domain] = mod.events
	for eventName, schema in mod.schemas do
		schemasRaw[eventName] = schema
	end
end

local Events = table.freeze(eventsRaw)
local Schemas = schemasRaw

-- Wire middleware: validator runs first (type checking), then logger (telemetry)
local validator = EventValidator.new(Schemas)
local logger = EventMiddleware.new()

local Bus = EventBus.new({ validator, logger })

--[=[
	@prop Events { [string]: { [string]: string } }
	@within GameEvents
	Grouped event name constants, organized by domain (e.g., `Events.Worker.WorkerHired`).
]=]

--[=[
	@prop Bus EventBus
	@within GameEvents
	The singleton event bus wired with validation and logging middleware.
]=]

return table.freeze({
	Events = Events,
	Bus = Bus,
})
