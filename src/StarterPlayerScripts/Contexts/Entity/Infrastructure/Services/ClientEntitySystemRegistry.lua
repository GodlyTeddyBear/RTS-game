--!strict

local ClientEntitySystemRegistry = {}
ClientEntitySystemRegistry.__index = ClientEntitySystemRegistry

local DEBUG_PREFIX = "[AnimationPipeline]"
local DEFAULT_PHASE = "Playback"
local GROUPS = table.freeze({
	Heartbeat = table.freeze({ "Reconcile", "Setup", "Playback", "Cleanup" }),
	PreSimulation = table.freeze({ "Procedural" }),
	Render = table.freeze({ "Render" }),
})

function ClientEntitySystemRegistry.new()
	return setmetatable({
		_systemsByPhase = {},
		_systemsByName = {},
	}, ClientEntitySystemRegistry)
end

function ClientEntitySystemRegistry:Register(systemName: string, system: any, phaseName: string?)
	assert(type(systemName) == "string" and systemName ~= "", "Client Entity system name is required")
	assert(type(system) == "table" and type(system.Run) == "function", "Client Entity system must expose Run")
	assert(self._systemsByName[systemName] == nil, ("Duplicate client Entity system '%s'"):format(systemName))

	local resolvedPhase = if type(phaseName) == "string" and phaseName ~= "" then phaseName else DEFAULT_PHASE
	self._systemsByPhase[resolvedPhase] = self._systemsByPhase[resolvedPhase] or {}
	self._systemsByName[systemName] = system
	table.insert(self._systemsByPhase[resolvedPhase], system)
	if string.find(systemName, "Animation", 1, true) ~= nil then
		warn(DEBUG_PREFIX, "registered system", systemName, "phase", resolvedPhase)
	end
end

function ClientEntitySystemRegistry:RunPhase(phaseName: string)
	for _, system in ipairs(self._systemsByPhase[phaseName] or {}) do
		system:Run()
	end
end

function ClientEntitySystemRegistry:RunGroup(groupName: string)
	for _, phaseName in ipairs(GROUPS[groupName] or {}) do
		self:RunPhase(phaseName)
	end
end

function ClientEntitySystemRegistry:Run()
	self:RunGroup("Heartbeat")
end

function ClientEntitySystemRegistry:Destroy()
	for _, system in pairs(self._systemsByName) do
		if type(system.Destroy) == "function" then
			system:Destroy()
		end
	end
	table.clear(self._systemsByPhase)
	table.clear(self._systemsByName)
end

return ClientEntitySystemRegistry
