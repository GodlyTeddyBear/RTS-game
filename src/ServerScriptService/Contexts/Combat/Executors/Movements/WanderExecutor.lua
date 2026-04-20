--!strict

--[[
    WanderExecutor - Pathfind to a random point within WanderRadius using SimplePath.

    Non-committed (cancellable). On Start, pathfinds to the WanderTarget
    provided in actionData. Returns "Success" on arrival, "Running" while
    in transit, "Fail" on pathfinding error.

    PositionComponent stores a CFrame and is the source of truth for perception.
    SimplePath controls Humanoid:MoveTo() directly on the model.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)
local BaseExecutor = require(script.Parent.Parent.Base.BaseExecutor)
local PathfindingHelper = require(script.Parent.Parent.Helpers.PathfindingHelper)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices

local WanderExecutor = {}
WanderExecutor.__index = WanderExecutor
setmetatable(WanderExecutor, { __index = BaseExecutor })

export type TWanderExecutor = typeof(setmetatable(
	{} :: { Config: ExecutorTypes.TExecutorConfig, _promises: { [Entity]: any } },
	WanderExecutor
))

function WanderExecutor.new(): TWanderExecutor
	local self = BaseExecutor.new({
		ActionId = "Wander",
		IsCommitted = false,
		Duration = nil,
	})
	self._promises = {}
	return setmetatable(self :: any, WanderExecutor)
end

function WanderExecutor:_CleanupEntity(entity: Entity)
	if self._promises[entity] then
		self._promises[entity]:cancel()
		self._promises[entity] = nil
	end
end

function WanderExecutor:Start(entity: Entity, actionData: { [string]: any }?, services: TActionServices): (boolean, string?)
	if not actionData or not actionData.WanderTarget then
		return false, "No wander target"
	end

	self:_CleanupEntity(entity)

	local path = PathfindingHelper.CreatePath(entity, services)
	if not path then
		return false, "Failed to create pathfinding path"
	end

	local wanderTarget = actionData.WanderTarget
	local targetVec = Vector3.new(wanderTarget.X, wanderTarget.Y, wanderTarget.Z)
	self._promises[entity] = PathfindingHelper.RunPath(path, targetVec)

	services.NPCEntityFactory:SetLocomotionState(entity, "Wandering")
	return true, nil
end

function WanderExecutor:Tick(entity: Entity, _deltaTime: number, services: TActionServices): string
	local npc = services.NPCEntityFactory
	local promise = self._promises[entity]

	if not promise or promise:getStatus() == Promise.Status.Rejected then
		return "Fail"
	end

	if promise:getStatus() == Promise.Status.Resolved then
		npc:SetLocomotionState(entity, "Idle")
		return "Success"
	end

	npc:SetLocomotionState(entity, "Wandering")
	return "Running"
end

function WanderExecutor:Cancel(entity: Entity, services: TActionServices)
	self:_CleanupEntity(entity)
	services.NPCEntityFactory:SetLocomotionState(entity, "Idle")
end

function WanderExecutor:Complete(entity: Entity, _services: TActionServices)
	self:_CleanupEntity(entity)
end

return WanderExecutor
