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
setmetatable(StructureECSWorldService, BaseECSWorldService)

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
	@param registry any -- The dependency registry for this context.
	@param name string -- The registered module name.
]=]
function StructureECSWorldService:Init(registry: any, name: string)
	BaseECSWorldService.Init(self, registry, name)
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
