--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Orient = require(ReplicatedStorage.Utilities.Orient)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local EnemyActionExecutionSystem = {}
EnemyActionExecutionSystem.__index = EnemyActionExecutionSystem

local GOAL_REACHED_DISTANCE = 4
local ATTACK_ANIMATION_STATE = "Attack"
local MOVE_ANIMATION_STATE = "Walk"
local IDLE_ANIMATION_STATE = "Idle"

function EnemyActionExecutionSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, EnemyActionExecutionSystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	self._baseContext = dependencies.BaseContext
	self._structureContext = dependencies.StructureContext
	return self
end

function EnemyActionExecutionSystem:Run()
	-- READS: Enemy.Role [AUTHORITATIVE], Enemy.PathState [AUTHORITATIVE], Enemy.AttackCooldown [AUTHORITATIVE], Entity.Transform [AUTHORITATIVE], Entity.Target [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE], AI.ActionIntent [AUTHORITATIVE]
	-- WRITES: Entity.Transform [AUTHORITATIVE], Entity.Target [AUTHORITATIVE], Enemy.PathState [AUTHORITATIVE], Enemy.AttackCooldown [AUTHORITATIVE], Enemy.CurrentMoveSpeed [AUTHORITATIVE], Enemy.AnimationState [AUTHORITATIVE], Enemy.AnimationLooping [AUTHORITATIVE], Enemy.AliveTag, Enemy.GoalReachedTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Enemy",
		Keys = { "AliveTag", "Role", "PathState", "AttackCooldown", "CurrentMoveSpeed" },
	})
	if not queryResult.success then
		return
	end

	local deltaTime = ServerScheduler:GetDeltaTime()
	local now = os.clock()

	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now, deltaTime)
	end
end

function EnemyActionExecutionSystem:_RunEntity(entity: number, now: number, deltaTime: number)
	local role = self:_GetComponent(entity, "Role", "Enemy")
	local pathState = self:_GetComponent(entity, "PathState", "Enemy")
	local attackCooldown = self:_GetComponent(entity, "AttackCooldown", "Enemy")
	local currentMoveSpeed = self:_GetComponent(entity, "CurrentMoveSpeed", "Enemy")
	local transform = self:_GetComponent(entity, "Transform", "Entity")
	local targetState = self:_GetComponent(entity, "Target", "Entity")
	local actionState = self:_GetComponent(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	local actionIntent = self:_GetComponent(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)

	if type(role) ~= "table" or type(transform) ~= "table" or typeof(transform.CFrame) ~= "CFrame" then
		return
	end

	local currentCFrame = transform.CFrame
	local actionId = if type(actionIntent) == "table" and type(actionIntent.ActionId) == "string" then actionIntent.ActionId else nil
	local data = if type(actionIntent) == "table" and type(actionIntent.Data) == "table" then actionIntent.Data else nil

	if type(actionState) == "table" and actionState.Status == AISharedContract.ActionStatus.Running and actionId == "EnemyAttack" then
		self:_RunAttack(entity, role, attackCooldown, currentCFrame, targetState, actionIntent, data, now)
		return
	end

	if type(actionState) == "table" and actionState.Status == AISharedContract.ActionStatus.Running and actionId == "EnemyAdvance" then
		self:_SetTarget(entity, nil, nil)
		self:_RunAdvance(entity, role, pathState, currentMoveSpeed, currentCFrame, data, deltaTime)
		return
	end

	self:_SetAnimation(entity, IDLE_ANIMATION_STATE, true)
	self:_SetCurrentMoveSpeed(entity, 0)
	self:_SetPathState(entity, {
		GoalPosition = if type(pathState) == "table" then pathState.GoalPosition else nil,
		IsMoving = false,
	})
end

function EnemyActionExecutionSystem:_RunAttack(
	entity: number,
	role: any,
	attackCooldown: any,
	currentCFrame: CFrame,
	targetState: any,
	actionIntent: any,
	data: any,
	now: number
)
	local targetKind = if type(data) == "table" and type(data.TargetKind) == "string" then data.TargetKind else nil
	local targetEntity = if type(actionIntent) == "table" and type(actionIntent.TargetEntity) == "number"
		then actionIntent.TargetEntity
		else if type(targetState) == "table" then targetState.TargetEntity else nil
	local lastAttackTime = if type(attackCooldown) == "table" and type(attackCooldown.LastAttackTime) == "number"
		then attackCooldown.LastAttackTime
		else 0
	local cooldown = if type(attackCooldown) == "table" and type(attackCooldown.Cooldown) == "number"
		then attackCooldown.Cooldown
		else (type(role.AttackCooldown) == "number" and role.AttackCooldown or 0)

	self:_SetCurrentMoveSpeed(entity, 0)
	self:_SetPathState(entity, {
		GoalPosition = if type(data) == "table" and typeof(data.TargetPosition) == "Vector3" then data.TargetPosition else nil,
		IsMoving = false,
	})
	self:_SetTarget(entity, targetEntity, targetKind)
	self:_SetAnimation(entity, ATTACK_ANIMATION_STATE, false)

	if cooldown > 0 and (now - lastAttackTime) < cooldown then
		return
	end

	if targetKind == "Base" then
		local damageResult = self._baseContext:ApplyDamage(role.Damage)
		if damageResult.success then
			self:_SetAttackCooldown(entity, cooldown, now)
		end
		return
	end

	if targetKind == "Structure" and type(targetEntity) == "number" then
		local damageResult = self._structureContext:ApplyDamage(targetEntity, role.Damage)
		if damageResult.success then
			self:_SetAttackCooldown(entity, cooldown, now)
		end
	end
end

function EnemyActionExecutionSystem:_RunAdvance(
	entity: number,
	role: any,
	pathState: any,
	currentMoveSpeed: any,
	currentCFrame: CFrame,
	data: any,
	deltaTime: number
)
	local goalPosition = if type(data) == "table" and typeof(data.GoalPosition) == "Vector3" then data.GoalPosition else nil
	if goalPosition == nil then
		self:_SetAnimation(entity, IDLE_ANIMATION_STATE, true)
		self:_SetCurrentMoveSpeed(entity, 0)
		return
	end

	local currentPosition = currentCFrame.Position
	local moveSpeed = if type(currentMoveSpeed) == "table" and type(currentMoveSpeed.Value) == "number"
		then currentMoveSpeed.Value
		else role.MoveSpeed
	local nextPosition = Orient.MoveTowards(currentPosition, goalPosition, moveSpeed * deltaTime)
	local nextCFrame = Orient.BuildLookAt(nextPosition, goalPosition) or CFrame.new(nextPosition)

	self:_SetTransform(entity, nextCFrame)
	self:_SetCurrentMoveSpeed(entity, moveSpeed)
	self:_SetPathState(entity, {
		GoalPosition = goalPosition,
		IsMoving = true,
	})
	self:_SetAnimation(entity, MOVE_ANIMATION_STATE, true)

	local boundInstanceResult = self._entityContext:GetBoundInstance(entity)
	local boundInstance = if boundInstanceResult.success then boundInstanceResult.value else nil
	if boundInstance ~= nil and boundInstance:IsA("Model") then
		boundInstance:PivotTo(nextCFrame)
	end

	if (goalPosition - nextPosition).Magnitude <= GOAL_REACHED_DISTANCE then
		self._baseContext:ApplyDamage(role.Damage)
		self._entityContext:DestroyEntity(entity)
	end
end

function EnemyActionExecutionSystem:_GetComponent(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	if not result.success then
		return nil
	end
	return result.value
end

function EnemyActionExecutionSystem:_SetTransform(entity: number, cframe: CFrame)
	self._entityFactory:Set(entity, "Transform", {
		CFrame = cframe,
	}, "Entity")
end

function EnemyActionExecutionSystem:_SetCurrentMoveSpeed(entity: number, moveSpeed: number)
	self._entityFactory:Set(entity, "CurrentMoveSpeed", {
		Value = moveSpeed,
	}, "Enemy")
end

function EnemyActionExecutionSystem:_SetPathState(entity: number, pathState: any)
	self._entityFactory:Set(entity, "PathState", pathState, "Enemy")
end

function EnemyActionExecutionSystem:_SetAttackCooldown(entity: number, cooldown: number, lastAttackTime: number)
	self._entityFactory:Set(entity, "AttackCooldown", {
		Cooldown = cooldown,
		LastAttackTime = lastAttackTime,
	}, "Enemy")
end

function EnemyActionExecutionSystem:_SetTarget(entity: number, targetEntity: number?, targetKind: string?)
	self._entityFactory:Set(entity, "Target", {
		TargetEntity = targetEntity,
		TargetKind = targetKind,
	}, "Entity")
end

function EnemyActionExecutionSystem:_SetAnimation(entity: number, animationState: string, isLooping: boolean)
	self._entityFactory:Set(entity, "AnimationState", animationState, "Enemy")
	self._entityFactory:Set(entity, "AnimationLooping", isLooping, "Enemy")
end

return EnemyActionExecutionSystem
