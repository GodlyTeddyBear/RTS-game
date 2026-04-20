--!strict

--[[
    ChaseExecutor - Pathfind toward a target entity using SimplePath.

    Non-committed (cancellable). Creates a SimplePath on Start and follows
    the target. Recomputes the path when the target moves beyond a threshold.
    Returns "Running" while in transit, "Fail" if pathfinding errors or
    the target dies.

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

local ChaseExecutor = {}
ChaseExecutor.__index = ChaseExecutor
setmetatable(ChaseExecutor, { __index = BaseExecutor })

export type TChaseExecutor = typeof(setmetatable(
	{} :: { Config: ExecutorTypes.TExecutorConfig, _promises: { [Entity]: any }, _paths: { [Entity]: any }, _lastTargetPos: { [Entity]: Vector3 } },
	ChaseExecutor
))

function ChaseExecutor.new(): TChaseExecutor
	local self = BaseExecutor.new({
		ActionId = "Chase",
		IsCommitted = false,
		Duration = nil,
	})
	-- Per-entity state (executor instances are singletons shared across entities)
	self._promises = {}
	self._paths = {}
	self._lastTargetPos = {}
	return setmetatable(self :: any, ChaseExecutor)
end

function ChaseExecutor:_CleanupEntity(entity: Entity)
	if self._promises[entity] then
		self._promises[entity]:cancel()
		self._promises[entity] = nil
	end
	self._paths[entity] = nil
	self._lastTargetPos[entity] = nil
end

function ChaseExecutor:_RecomputePath(entity: Entity, targetVec: Vector3, services: TActionServices)
	-- Cancel the old promise (stops the old path) and start a fresh one
	if self._promises[entity] then
		self._promises[entity]:cancel()
	end

	local path = PathfindingHelper.CreatePath(entity, services)
	if not path then
		self._promises[entity] = nil
		self._paths[entity] = nil
		return
	end

	self._paths[entity] = path
	self._lastTargetPos[entity] = targetVec
	self._promises[entity] = PathfindingHelper.RunPath(path, targetVec)
end

--[=[
	Start chasing a target entity.
	@within ChaseExecutor
	@param entity Entity
	@param actionData { TargetEntity: Entity, MoveTarget: Vector3 }? -- Must contain TargetEntity
	@param services TActionServices
	@return boolean -- True if pathfinding started successfully
	@return string? -- Failure reason if false
]=]
function ChaseExecutor:Start(entity: Entity, actionData: { [string]: any }?, services: TActionServices): (boolean, string?)
	local npc = services.NPCEntityFactory

	-- Validate target entity exists in action data
	if not actionData or not actionData.TargetEntity then
		return false, "No target entity for chase"
	end

	-- Validate target is still alive
	if not npc:IsAlive(actionData.TargetEntity) then
		return false, "Target is not alive"
	end

	-- Clean up any previous pathfinding state
	self:_CleanupEntity(entity)

	-- Create a fresh SimplePath for this chase
	local path = PathfindingHelper.CreatePath(entity, services)
	if not path then
		return false, "Failed to create pathfinding path"
	end

	-- Get initial target position
	local targetPos = npc:GetPosition(actionData.TargetEntity)
	if not targetPos then
		pcall(function()
			path:Destroy()
		end)
		return false, "Target position unavailable"
	end

	-- Start pathfinding and track state
	local targetVec = targetPos.CFrame.Position
	self._paths[entity] = path
	self._lastTargetPos[entity] = targetVec
	self._promises[entity] = PathfindingHelper.RunPath(path, targetVec)

	npc:SetLocomotionState(entity, "Moving")
	npc:SetTarget(entity, actionData.TargetEntity)
	return true, nil
end

--[=[
	Continue chasing the target, recomputing the path if target moved far enough.
	@within ChaseExecutor
	@param entity Entity
	@param _deltaTime number
	@param services TActionServices
	@return string -- "Running" while in transit, "Fail" if pathfinding failed or target died
]=]
function ChaseExecutor:Tick(entity: Entity, _deltaTime: number, services: TActionServices): string
	local npc = services.NPCEntityFactory

	-- Validate action is still active
	local actionComp = npc:GetCombatAction(entity)
	if not actionComp or not actionComp.ActionData then
		return "Fail"
	end

	-- Validate target still exists and is alive
	local targetEntity: Entity = actionComp.ActionData.TargetEntity
	if not targetEntity or not npc:IsAlive(targetEntity) then
		return "Fail"
	end

	-- Validate the pathfinding promise is still active
	local promise = self._promises[entity]
	if not promise or promise:getStatus() == Promise.Status.Rejected then
		return "Fail"
	end

	local behaviorConfig = npc:GetBehaviorConfig(entity)
	local recomputeThreshold = if behaviorConfig then behaviorConfig.ChaseRecomputeThreshold else 5

	local targetPos = npc:GetPosition(targetEntity)
	if targetPos then
		local targetVec = targetPos.CFrame.Position
		local lastTarget: Vector3? = self._lastTargetPos[entity]

		-- Return "Success" as soon as we enter attack range so Phase 3 resets the
		-- action and the BT can immediately queue an attack on the next tick.
		-- This prevents the NPC from overshooting while waiting for the BT interval.
		local myPos = npc:GetPosition(entity)
		if myPos and behaviorConfig then
			local distSq = (targetVec - myPos.CFrame.Position).Magnitude
			if distSq <= behaviorConfig.AttackEnterRange then
				return "Success"
			end
		end

		-- Recompute path if target moved beyond threshold (avoids pathfinding every tick)
		if lastTarget and (targetVec - lastTarget).Magnitude > recomputeThreshold then
			self:_RecomputePath(entity, targetVec, services)
			-- Recheck promise after recompute (path creation may have failed)
			if not self._promises[entity] then
				return "Fail"
			end
		end
	end

	npc:SetLocomotionState(entity, "Moving")
	return "Running"
end

function ChaseExecutor:Cancel(entity: Entity, services: TActionServices)
	self:_CleanupEntity(entity)
	services.NPCEntityFactory:SetLocomotionState(entity, "Idle")
end

function ChaseExecutor:Complete(entity: Entity, _services: TActionServices)
	self:_CleanupEntity(entity)
end

return ChaseExecutor
