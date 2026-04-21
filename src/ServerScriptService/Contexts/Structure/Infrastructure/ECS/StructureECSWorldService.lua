--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class StructureECSWorldService
	Owns the isolated JECS world used by StructureContext.
	@server
]=]
local StructureECSWorldService = {}
StructureECSWorldService.__index = StructureECSWorldService

--[=[
	Creates a new isolated JECS world service.
	@within StructureECSWorldService
	@return StructureECSWorldService -- The new service instance.
]=]
function StructureECSWorldService.new()
	local self = setmetatable({}, StructureECSWorldService)
	self._world = JECS.World.new()
	return self
end

--[=[
	Initializes the service lifecycle hook.
	@within StructureECSWorldService
	@param _registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function StructureECSWorldService:Init(_registry: any, _name: string)
end

--[=[
	Returns the isolated structure JECS world.
	@within StructureECSWorldService
	@return any -- The authoritative JECS world.
]=]
function StructureECSWorldService:GetWorld()
	return self._world
end

return StructureECSWorldService
