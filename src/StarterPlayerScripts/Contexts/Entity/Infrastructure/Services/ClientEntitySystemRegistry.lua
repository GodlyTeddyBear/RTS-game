--!strict

local ClientEntitySystemRegistry = {}
ClientEntitySystemRegistry.__index = ClientEntitySystemRegistry

function ClientEntitySystemRegistry.new()
	return setmetatable({
		_systems = {},
		_systemsByName = {},
	}, ClientEntitySystemRegistry)
end

function ClientEntitySystemRegistry:Register(systemName: string, system: any)
	assert(type(systemName) == "string" and systemName ~= "", "Client Entity system name is required")
	assert(type(system) == "table" and type(system.Run) == "function", "Client Entity system must expose Run")
	assert(self._systemsByName[systemName] == nil, ("Duplicate client Entity system '%s'"):format(systemName))
	self._systemsByName[systemName] = system
	table.insert(self._systems, system)
end

function ClientEntitySystemRegistry:Run()
	for _, system in ipairs(self._systems) do
		system:Run()
	end
end

function ClientEntitySystemRegistry:Destroy()
	for _, system in ipairs(self._systems) do
		if type(system.Destroy) == "function" then
			system:Destroy()
		end
	end
	table.clear(self._systems)
	table.clear(self._systemsByName)
end

return ClientEntitySystemRegistry
