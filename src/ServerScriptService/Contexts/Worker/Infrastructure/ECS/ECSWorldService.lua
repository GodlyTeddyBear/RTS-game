--!strict

--[[
    ECS World Service - Singleton JECS world for Worker context.

    Responsibilities:
    - Create and manage JECS world instance
    - Provide world access to other services

    Pattern: Singleton per server
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local JECS = require(Packages.JECS)

local ECSWorldService = {}
ECSWorldService.__index = ECSWorldService

export type TECSWorldService = typeof(setmetatable({} :: { World: any }, ECSWorldService))

function ECSWorldService.new(): TECSWorldService
	local self = setmetatable({}, ECSWorldService)

	-- Create JECS world (singleton)
	self.World = JECS.World.new()

	return self
end

function ECSWorldService:GetWorld(): any
	return self.World
end

return ECSWorldService
