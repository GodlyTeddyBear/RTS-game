--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)

local EntityCommandAdapter = {}

function EntityCommandAdapter.Create(operationName: string, methodName: string)
	local Adapter = {}
	Adapter.__index = Adapter
	setmetatable(Adapter, BaseCommand)

	function Adapter.new()
		local self = BaseCommand.new("Entity", operationName)
		self._methodName = methodName
		return setmetatable(self, Adapter)
	end

	function Adapter:Init(registry: any, _name: string)
		self:_RequireDependency(registry, "_kernelService", "EntityKernelService")
	end

	function Adapter:Execute(...: any): any
		return self._kernelService[self._methodName](self._kernelService, ...)
	end

	return Adapter
end

return EntityCommandAdapter
