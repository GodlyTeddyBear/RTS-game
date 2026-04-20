--!strict

--[=[
	@class CombatECSWorldService
	Creates and manages a dedicated JECS world for combat entities (NPCs and attacks).
	@server
]=]

--[[
    CombatECSWorldService - Separate JECS world for combat entities.

    Responsibilities:
    - Create and manage a dedicated JECS world for NPC/combat entities
    - Provide world access to other services
    - Isolated from Worker context's JECS world

    Pattern: Singleton per server
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local JECS = require(Packages.JECS)

local CombatECSWorldService = {}
CombatECSWorldService.__index = CombatECSWorldService

export type TCombatECSWorldService = typeof(setmetatable({} :: { World: any }, CombatECSWorldService))

function CombatECSWorldService.new(): TCombatECSWorldService
	local self = setmetatable({}, CombatECSWorldService)

	-- Create dedicated JECS world for combat (separate from Worker world)
	self.World = JECS.World.new()

	return self
end

--[=[
	Get the JECS world instance.
	@within CombatECSWorldService
	@return any -- JECS world
]=]
function CombatECSWorldService:GetWorld(): any
	return self.World
end

return CombatECSWorldService
