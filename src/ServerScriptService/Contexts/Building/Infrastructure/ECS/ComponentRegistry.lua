--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local JECS = require(Packages.JECS)

--[=[
	@class BuildingComponentRegistry
	Registers all ECS components for the Building context.
	@server
]=]
local ComponentRegistry = {}
ComponentRegistry.__index = ComponentRegistry

export type TComponentRegistry = typeof(setmetatable(
	{} :: {
		_world: any,
		BuildingComponent: any,
		GameObjectComponent: any,
		DirtyTag: any,
	},
	ComponentRegistry
))

function ComponentRegistry.new(): TComponentRegistry
	local self = setmetatable({}, ComponentRegistry)
	self._world = nil :: any
	self.BuildingComponent = nil :: any
	self.GameObjectComponent = nil :: any
	self.DirtyTag = nil :: any
	return self
end

function ComponentRegistry:Init(registry: any, _name: string)
	local worldService = registry:Get("BuildingECSWorldService")
	self._world = worldService:GetWorld()

	self.BuildingComponent = self._world:component()
	self._world:set(self.BuildingComponent, JECS.Name, "BuildingComponent")

	self.GameObjectComponent = self._world:component()
	self._world:set(self.GameObjectComponent, JECS.Name, "BuildingGameObjectComponent")

	self.DirtyTag = self._world:component()
	self._world:set(self.DirtyTag, JECS.Name, "BuildingDirtyTag")
end

return ComponentRegistry
