--!strict

--[[
	ECS World Service - Singleton JECS world for Lot context.

	Responsibilities:
	- Create and manage JECS world instance
	- Provide world access to other services

	Pattern: Singleton per server, separate from Worker world
]]

--[=[
	@class ECSWorldService
	Manages the singleton JECS world instance for the Lot context.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local JECS = require(Packages.JECS)

local ECSWorldService = {}
ECSWorldService.__index = ECSWorldService

--[=[
	Create a new ECSWorldService with a fresh JECS world.
	@within ECSWorldService
	@return ECSWorldService -- Service instance
]=]
function ECSWorldService.new()
	local self = setmetatable({}, ECSWorldService)

	-- Create dedicated JECS world for lots (separate from Worker world)
	self.World = JECS.World.new()

	return self
end

--[=[
	Get the JECS world instance.
	@within ECSWorldService
	@return any -- The JECS world instance
]=]
function ECSWorldService:GetWorld(): any
	return self.World
end

return ECSWorldService
