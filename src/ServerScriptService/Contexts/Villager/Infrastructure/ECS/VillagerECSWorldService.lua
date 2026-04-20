--!strict

--[=[
	@class VillagerECSWorldService
	Creates and manages the JECS world for villager entities.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

local VillagerECSWorldService = {}
VillagerECSWorldService.__index = VillagerECSWorldService

export type TVillagerECSWorldService = typeof(setmetatable({} :: { World: any }, VillagerECSWorldService))

function VillagerECSWorldService.new(): TVillagerECSWorldService
	local self = setmetatable({}, VillagerECSWorldService)
	self.World = JECS.World.new()
	return self
end

--[=[
	Gets the JECS world managing all villager entities.
	@within VillagerECSWorldService
	@return any -- The JECS world instance
]=]
function VillagerECSWorldService:GetWorld(): any
	return self.World
end

return VillagerECSWorldService
