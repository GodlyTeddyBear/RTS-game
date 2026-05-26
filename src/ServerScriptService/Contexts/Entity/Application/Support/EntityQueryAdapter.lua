--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)

local EntityQueryAdapter = {}

function EntityQueryAdapter.Create(operationName: string, methodName: string)
	local Adapter = {}
	Adapter.__index = Adapter
	setmetatable(Adapter, BaseQuery)

	function Adapter.new()
		local self = BaseQuery.new("Entity", operationName)
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

return EntityQueryAdapter
