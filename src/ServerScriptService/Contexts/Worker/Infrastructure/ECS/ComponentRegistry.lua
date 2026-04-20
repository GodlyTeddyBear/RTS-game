--!strict

--[[
    Component Registry - Defines all Worker ECS components.

    Responsibilities:
    - Define component types in JECS world
    - Provide component references to other services

    Pattern: Created once during WorkerContext initialization
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local JECS = require(Packages.JECS)
local ComponentTypes = require(ReplicatedStorage.Contexts.Worker.Types.ComponentTypes)

export type TWorkerComponent = ComponentTypes.TWorkerComponent
export type TAssignmentComponent = ComponentTypes.TAssignmentComponent
export type TPositionComponent = ComponentTypes.TPositionComponent
export type TGameObjectComponent = ComponentTypes.TGameObjectComponent
export type TMiningStateComponent = ComponentTypes.TMiningStateComponent
export type TEquipmentComponent = ComponentTypes.TEquipmentComponent
export type TDirtyTag = ComponentTypes.TDirtyTag

local ComponentRegistry = {}
ComponentRegistry.__index = ComponentRegistry

export type TComponentRegistry = typeof(setmetatable({} :: {
	World: any,
	WorkerComponent: TWorkerComponent,
	AssignmentComponent: TAssignmentComponent,
	PositionComponent: TPositionComponent,
	GameObjectComponent: TGameObjectComponent,
	MiningStateComponent: TMiningStateComponent,
	EquipmentComponent: TEquipmentComponent,
	DirtyTag: TDirtyTag,
	EntityTag: any,
}, ComponentRegistry))

function ComponentRegistry.new(): TComponentRegistry
	return setmetatable({}, ComponentRegistry)
end

function ComponentRegistry:Init(registry: any, _name: string)
	local world = registry:Get("World")
	self.World = world

	-- Define all components in JECS world
	self.WorkerComponent = world:component() :: TWorkerComponent
	world:set(self.WorkerComponent, JECS.Name, "Worker")
	self.AssignmentComponent = world:component() :: TAssignmentComponent
	world:set(self.AssignmentComponent, JECS.Name, "Assignment")
	self.PositionComponent = world:component() :: TPositionComponent
	world:set(self.PositionComponent, JECS.Name, "Position")
	self.GameObjectComponent = world:component() :: TGameObjectComponent
	world:set(self.GameObjectComponent, JECS.Name, "GameObject")
	self.MiningStateComponent = world:component() :: TMiningStateComponent
	world:set(self.MiningStateComponent, JECS.Name, "MiningState")
	self.EquipmentComponent = world:component() :: TEquipmentComponent
	world:set(self.EquipmentComponent, JECS.Name, "Equipment")
	self.DirtyTag = world:component() :: TDirtyTag
	world:set(self.DirtyTag, JECS.Name, "Dirty")
	self.EntityTag = world:component()
	world:set(self.EntityTag, JECS.Name, "Entity")
end

return ComponentRegistry
