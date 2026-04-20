--!strict

--[[
    FleeExecutor - Pathfind away from the nearest threat using SimplePath.

    Non-committed (cancellable). Computes a flee target point in the opposite
    direction from the threat and pathfinds to it. Recomputes when the threat
    moves significantly or when the flee destination is reached (to keep fleeing).
    Returns "Running" until cancelled by BT, "Success" if threat dies,
    "Fail" on pathfinding error.

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

local FleeExecutor = {}
FleeExecutor.__index = FleeExecutor
setmetatable(FleeExecutor, { __index = BaseExecutor })

export type TFleeExecutor = typeof(setmetatable(
	{} :: { Config: ExecutorTypes.TExecutorConfig, _promises: { [Entity]: any }, _lastThreatPos: { [Entity]: Vector3 } },
	FleeExecutor
))

function FleeExecutor.new(): TFleeExecutor
	local self = BaseExecutor.new({
		ActionId = "Flee",
		IsCommitted = false,
		Duration = nil,
	})
	self._promises = {}
	self._lastThreatPos = {}
	return setmetatable(self :: any, FleeExecutor)
end

function FleeExecutor:_CleanupEntity(entity: Entity)
	if self._promises[entity] then
		self._promises[entity]:cancel()
		self._promises[entity] = nil
	end
	self._lastThreatPos[entity] = nil
end

local function _ComputeFleeTarget(currentPos: Vector3, threatPos: Vector3, fleeDistance: number): Vector3
	local awayDir = Vector3.new(currentPos.X - threatPos.X, 0, currentPos.Z - threatPos.Z)
	if awayDir.Magnitude < 0.01 then
		local angle = math.random() * math.pi * 2
		awayDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	return currentPos + awayDir.Unit * fleeDistance
end

function FleeExecutor:_RecomputePath(entity: Entity, currentPos: Vector3, threatVec: Vector3, fleeDistance: number, services: TActionServices)
	if self._promises[entity] then
		self._promises[entity]:cancel()
	end

	local path = PathfindingHelper.CreatePath(entity, services)
	if not path then
		self._promises[entity] = nil
		return
	end

	local fleeTarget = _ComputeFleeTarget(currentPos, threatVec, fleeDistance)
	self._lastThreatPos[entity] = threatVec
	self._promises[entity] = PathfindingHelper.RunPath(path, fleeTarget)
end

function FleeExecutor:Start(entity: Entity, actionData: { [string]: any }?, services: TActionServices): (boolean, string?)
	if not actionData or not actionData.ThreatEntity then
		return false, "No threat entity for flee"
	end

	local npc = services.NPCEntityFactory

	self:_CleanupEntity(entity)

	local path = PathfindingHelper.CreatePath(entity, services)
	if not path then
		return false, "Failed to create pathfinding path"
	end

	local myPos = npc:GetPosition(entity)
	local threatPos = npc:GetPosition(actionData.ThreatEntity)
	if not myPos or not threatPos then
		pcall(function()
			path:Destroy()
		end)
		return false, "Position data unavailable"
	end

	local behaviorConfig = npc:GetBehaviorConfig(entity)
	local fleeDistance = if behaviorConfig then behaviorConfig.FleeDistance else 15

	local currentPos = myPos.CFrame.Position
	local threatVec = threatPos.CFrame.Position
	local fleeTarget = _ComputeFleeTarget(currentPos, threatVec, fleeDistance)

	self._lastThreatPos[entity] = threatVec
	self._promises[entity] = PathfindingHelper.RunPath(path, fleeTarget)

	npc:SetLocomotionState(entity, "Fleeing")
	return true, nil
end

function FleeExecutor:Tick(entity: Entity, _deltaTime: number, services: TActionServices): string
	local npc = services.NPCEntityFactory

	local actionComp = npc:GetCombatAction(entity)
	if not actionComp or not actionComp.ActionData then
		return "Fail"
	end

	local threatEntity = actionComp.ActionData.ThreatEntity
	if not threatEntity or not npc:IsAlive(threatEntity) then
		return "Success"
	end

	local promise = self._promises[entity]
	if not promise or promise:getStatus() == Promise.Status.Rejected then
		return "Fail"
	end

	local myPos = npc:GetPosition(entity)
	local threatPos = npc:GetPosition(threatEntity)

	if myPos and threatPos then
		local behaviorConfig = npc:GetBehaviorConfig(entity)
		local recomputeThreshold = if behaviorConfig then behaviorConfig.FleeRecomputeThreshold else 5
		local fleeDistance = if behaviorConfig then behaviorConfig.FleeDistance else 15

		local threatVec = threatPos.CFrame.Position
		local lastThreat = self._lastThreatPos[entity]

		-- Recompute if threat moved significantly
		local threatMoved = lastThreat and (threatVec - lastThreat).Magnitude > recomputeThreshold
		-- Recompute if we've reached the flee point (keep running away)
		local reachedFlee = promise:getStatus() == Promise.Status.Resolved

		if threatMoved or reachedFlee then
			self:_RecomputePath(entity, myPos.CFrame.Position, threatVec, fleeDistance, services)
			if not self._promises[entity] then
				return "Fail"
			end
		end
	end

	npc:SetLocomotionState(entity, "Fleeing")
	return "Running"
end

function FleeExecutor:Cancel(entity: Entity, services: TActionServices)
	self:_CleanupEntity(entity)
	services.NPCEntityFactory:SetLocomotionState(entity, "Idle")
end

function FleeExecutor:Complete(entity: Entity, _services: TActionServices)
	self:_CleanupEntity(entity)
end

return FleeExecutor
