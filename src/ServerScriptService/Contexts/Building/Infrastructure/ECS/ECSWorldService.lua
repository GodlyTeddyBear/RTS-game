--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local JECS = require(Packages.JECS)

--[=[
	@class BuildingECSWorldService
	Singleton JECS world for the Building context.
	Kept separate from the Lot and Worker worlds to avoid cross-context entity leakage.
	@server
]=]
local ECSWorldService = {}
ECSWorldService.__index = ECSWorldService

export type TECSWorldService = typeof(setmetatable(
	{} :: {
		_world: any,
	},
	ECSWorldService
))

function ECSWorldService.new(): TECSWorldService
	local self = setmetatable({}, ECSWorldService)
	self._world = JECS.World.new()
	return self
end

function ECSWorldService:Init(_registry: any, _name: string) end

function ECSWorldService:GetWorld(): any
	return self._world
end

return ECSWorldService
