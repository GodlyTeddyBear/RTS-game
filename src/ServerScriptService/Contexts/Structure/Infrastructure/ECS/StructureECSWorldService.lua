--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

--[=[
	@class StructureECSWorldService
	Owns the isolated JECS world used by StructureContext.
	@server
]=]
local StructureECSWorldService = {}
StructureECSWorldService.__index = StructureECSWorldService
setmetatable(StructureECSWorldService, { __index = BaseECSWorldService })

--[=[
	Creates a new isolated JECS world service.
	@within StructureECSWorldService
	@return StructureECSWorldService -- The new service instance.
]=]
function StructureECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Structure"), StructureECSWorldService)
end

--[=[
	Initializes the service lifecycle hook.
	@within StructureECSWorldService
	@param _registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function StructureECSWorldService:Init(_registry: any, _name: string)
	BaseECSWorldService.Init(self, _registry, _name)
end

--[=[
	Returns the isolated structure JECS world.
	@within StructureECSWorldService
	@return any -- The authoritative JECS world.
]=]
function StructureECSWorldService:GetWorld()
	return BaseECSWorldService.GetWorld(self)
end

return StructureECSWorldService
