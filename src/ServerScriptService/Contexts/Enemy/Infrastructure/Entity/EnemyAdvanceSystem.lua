--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Orient = require(ReplicatedStorage.Utilities.Orient)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local EnemyAdvanceSystem = {}
EnemyAdvanceSystem.__index = EnemyAdvanceSystem

local GOAL_REACHED_DISTANCE = 4
local ACTION_ADVANCE = "Advance"

function EnemyAdvanceSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, EnemyAdvanceSystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	self._baseContext = dependencies.BaseContext
	return self
end

function EnemyAdvanceSystem:Run()
	-- READS: Enemy.AdvanceState [AUTHORITATIVE], Enemy.Role [AUTHORITATIVE], Enemy.PathState [AUTHORITATIVE], Enemy.CurrentMoveSpeed [AUTHORITATIVE], Entity.Transform [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: Entity.Transform [AUTHORITATIVE], Enemy.PathState [AUTHORITATIVE], Enemy.CurrentMoveSpeed [AUTHORITATIVE], Enemy.AnimationState [DERIVED], Enemy.AnimationLooping [DERIVED]
	local queryResult = self._entityFactory:Query({
		FeatureName = "Enemy",
		Keys = { "AliveTag", "AdvanceState", "Role", "PathState", "CurrentMoveSpeed" },
	})
	if not queryResult.success then
		return
	end

	local deltaTime = ServerScheduler:GetDeltaTime()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, deltaTime)
	end
end

function EnemyAdvanceSystem:_RunEntity(entity: number, deltaTime: number)
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if type(actionState) ~= "table" or actionState.ActionId ~= ACTION_ADVANCE then
		if type(actionState) ~= "table" or actionState.ActionId == "Idle" then
			self:_SetCurrentMoveSpeed(entity, 0)
			self:_SetPathState(entity, self:_BuildStoppedPathState(entity))
			self:_SetAnimation(entity, "Idle", true)
		end
		return
	end

	local advanceState = self:_Get(entity, "AdvanceState", "Enemy")
	local goalPosition = if type(advanceState) == "table" then advanceState.GoalPosition else nil
	if typeof(goalPosition) ~= "Vector3" then
		self:_SetAnimation(entity, "Idle", true)
		self:_SetCurrentMoveSpeed(entity, 0)
		return
	end

	local role = self:_Get(entity, "Role", "Enemy")
	local transform = self:_Get(entity, "Transform", "Entity")
	if type(role) ~= "table" or type(transform) ~= "table" or typeof(transform.CFrame) ~= "CFrame" then
		return
	end

	local moveSpeed = if type(role.MoveSpeed) == "number" then role.MoveSpeed else 0
	local currentPosition = transform.CFrame.Position
	local nextPosition = Orient.MoveTowards(currentPosition, goalPosition, moveSpeed * deltaTime)
	local nextCFrame = Orient.BuildLookAt(nextPosition, goalPosition) or CFrame.new(nextPosition)

	self._entityFactory:Set(entity, "Transform", {
		CFrame = nextCFrame,
	}, "Entity")
	self:_SetCurrentMoveSpeed(entity, moveSpeed)
	self:_SetPathState(entity, {
		GoalPosition = goalPosition,
		IsMoving = true,
	})
	self:_SetAnimation(entity, "Walk", true)

	if (goalPosition - nextPosition).Magnitude <= GOAL_REACHED_DISTANCE then
		self._baseContext:ApplyDamage(role.Damage)
		self._entityContext:DestroyEntity(entity)
	end
end

function EnemyAdvanceSystem:_BuildStoppedPathState(entity: number): any
	local pathState = self:_Get(entity, "PathState", "Enemy")
	return {
		GoalPosition = if type(pathState) == "table" then pathState.GoalPosition else nil,
		IsMoving = false,
	}
end

function EnemyAdvanceSystem:_SetCurrentMoveSpeed(entity: number, moveSpeed: number)
	self._entityFactory:Set(entity, "CurrentMoveSpeed", {
		Value = moveSpeed,
	}, "Enemy")
end

function EnemyAdvanceSystem:_SetPathState(entity: number, pathState: any)
	self._entityFactory:Set(entity, "PathState", pathState, "Enemy")
end

function EnemyAdvanceSystem:_SetAnimation(entity: number, animationState: string, isLooping: boolean)
	self._entityFactory:Set(entity, "AnimationState", animationState, "Enemy")
	self._entityFactory:Set(entity, "AnimationLooping", isLooping, "Enemy")
end

function EnemyAdvanceSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyAdvanceSystem
