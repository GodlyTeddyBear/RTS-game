--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local BaseECSWorldService = require(ServerStorage.Utilities.ECSUtilities.BaseECSWorldService)

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

return StructureECSWorldService
