--!strict

--[=[
    @class UnitECSWorldService
    Owns the unit ECS world instance used by server-side unit entities and sync systems.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseECSWorldService = require(ServerStorage.Utilities.ECSUtilities.BaseECSWorldService)

local UnitECSWorldService = {}
UnitECSWorldService.__index = UnitECSWorldService
setmetatable(UnitECSWorldService, { __index = BaseECSWorldService })

-- Creates the unit ECS world service in the Unit namespace.
function UnitECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Unit"), UnitECSWorldService)
end

return UnitECSWorldService
