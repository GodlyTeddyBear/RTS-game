--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ReplicatedStorage.Utilities.PathfindingHelper)
local BoidsHelper = require(ReplicatedStorage.Utilities.BoidsHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)

local ADVANCE_BOIDS_SESSION_ID = "CombatAdvanceBase"
local GOAL_POSITION_EPSILON = 0.01

type EnemyMovementMode = EnemyTypes.EnemyMovementMode

type TPathMovementState = {
	Mode: "Path",
	Promise: any,
}

type TBoidsMovementState = {
	Mode: "Boids",
	SessionId: string,
	PreviousVelocity: Vector3,
}

type TMovementState = TPathMovementState | TBoidsMovementState

--[=[
	@class MovementService
	Owns Combat enemy movement runtime coordination for pathfinding and boids movement.
	@server
]=]
local MovementService = {}
MovementService.__index = MovementService

function MovementService.new()
	local self = setmetatable({}, MovementService)
	self._movementByEntity = {} :: { [number]: TMovementState }
	return self
end

function MovementService:Init(registry: any, _name: string)
	self._registry = registry
end

function MovementService:Start()
	self._enemyEntityFactory = self._registry:Get("EnemyEntityFactory")
end

function MovementService:StartAdvance(entity: number, movementMode: EnemyMovementMode): (boolean, string?)
	self:StopMovement(entity)

	local pathState = self._enemyEntityFactory:GetPathState(entity)
	if pathState == nil or pathState.GoalPosition == nil then
		return false, "MissingGoalPosition"
	end

	local resolvedMode = self:_ResolveAdvanceMode(movementMode, pathState.GoalPosition)
	if resolvedMode == nil then
		return false, "InvalidMovementMode"
	end

	if resolvedMode == "Boids" then
		if self:_StartBoids(entity, pathState.GoalPosition) then
			return true, nil
		end

		return false, "BoidsStartFailed"
	end

	if self:_StartPath(entity, pathState.GoalPosition) then
		return true, nil
	end

	return false, "PathStartFailed"
end

function MovementService:TickAdvance(entity: number): ("Running" | "Success" | "Fail", string?)
	local movementState = self._movementByEntity[entity]
	if movementState == nil then
		return "Fail", "MissingMovementState"
	end

	if movementState.Mode == "Boids" then
		return self:_TickBoids(entity, movementState)
	end

	return self:_TickPath(entity, movementState)
end

function MovementService:StopMovement(entity: number)
	local movementState = self._movementByEntity[entity]
	if movementState == nil then
		return
	end

	if movementState.Mode == "Path" then
		local promise = movementState.Promise
		if promise ~= nil and type(promise.cancel) == "function" then
			promise:cancel()
		end
	else
		BoidsHelper.CleanupEntity(entity, movementState.SessionId)
		self:_StopHumanoid(entity)
	end

	self._movementByEntity[entity] = nil
	self._enemyEntityFactory:SetPathMoving(entity, false)
end

function MovementService:CleanupAll()
	local entities = {}
	for entity in self._movementByEntity do
		table.insert(entities, entity)
	end

	for _, entity in ipairs(entities) do
		self:StopMovement(entity)
	end

	BoidsHelper.CleanupAllSessions()
end

function MovementService:_GetRoleName(entity: number): string?
	local role = self._enemyEntityFactory:GetRole(entity)
	return if role ~= nil then role.Role else nil
end

function MovementService:_GetAgentParams(entity: number): { [string]: any }
	local roleName = self:_GetRoleName(entity)
	if roleName ~= nil then
		local config = CombatMovementConfig.AGENT_PARAMS_BY_ROLE[roleName]
		if config ~= nil then
			return config
		end
	end

	return CombatMovementConfig.DEFAULT_AGENT_PARAMS
end

function MovementService:_GetBoidsOptions(): BoidsHelper.TBoidsOptions
	return {
		Config = BoidsConfig,
		GetPosition = function(entity: number): Vector3?
			local modelRef = self._enemyEntityFactory:GetModelRef(entity)
			local model = if modelRef ~= nil then modelRef.Model else nil
			local primaryPart = if model ~= nil then model.PrimaryPart else nil
			return if primaryPart ~= nil then primaryPart.Position else nil
		end,
	}
end

function MovementService:_ResolveAdvanceMode(
	movementMode: EnemyMovementMode,
	goalPosition: Vector3
): ("Path" | "Boids")?
	if movementMode == "Path" or movementMode == "Boids" then
		return movementMode
	end

	if movementMode == "Any" then
		return if self:_CountBoidsCapableEntitiesAtGoal(goalPosition) > 1 then "Boids" else "Path"
	end

	return nil
end

function MovementService:_CountBoidsCapableEntitiesAtGoal(goalPosition: Vector3): number
	local groupSize = 0
	for _, aliveEntity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
		if self:_CanEntityUseBoidsAtGoal(aliveEntity, goalPosition) then
			groupSize += 1
		end
	end

	return groupSize
end

function MovementService:_CanEntityUseBoidsAtGoal(entity: number, goalPosition: Vector3): boolean
	local pathState = self._enemyEntityFactory:GetPathState(entity)
	if pathState == nil or pathState.GoalPosition == nil then
		return false
	end

	if (pathState.GoalPosition - goalPosition).Magnitude > GOAL_POSITION_EPSILON then
		return false
	end

	local roleName = self:_GetRoleName(entity)
	local roleConfig = if roleName ~= nil then EnemyConfig.Roles[roleName] else nil
	if roleConfig == nil then
		return false
	end

	return roleConfig.MovementMode == "Any" or roleConfig.MovementMode == "Boids"
end

function MovementService:_StartBoids(entity: number, goalPosition: Vector3): boolean
	local options = self:_GetBoidsOptions()
	if not BoidsHelper.InitGroupMovement(entity, ADVANCE_BOIDS_SESSION_ID, goalPosition, options) then
		return false
	end

	self._movementByEntity[entity] = {
		Mode = "Boids",
		SessionId = ADVANCE_BOIDS_SESSION_ID,
		PreviousVelocity = Vector3.zero,
	}
	self._enemyEntityFactory:SetPathMoving(entity, true)
	return true
end

function MovementService:_StartPath(entity: number, goalPosition: Vector3): boolean
	local path = PathfindingHelper.CreatePath(entity, {
		EnemyEntityFactory = self._enemyEntityFactory,
	}, self:_GetAgentParams(entity), CombatMovementConfig.PATHFINDING)
	if path == nil then
		return false
	end

	self._movementByEntity[entity] = {
		Mode = "Path",
		Promise = PathfindingHelper.RunPath(path, goalPosition, entity, CombatMovementConfig.PATHFINDING),
	}
	self._enemyEntityFactory:SetPathMoving(entity, true)
	return true
end

function MovementService:_TickBoids(entity: number, movementState: TBoidsMovementState): ("Running" | "Success" | "Fail", string?)
	local moveDirection, hasArrived = BoidsHelper.TickEntity(
		entity,
		movementState.SessionId,
		movementState.PreviousVelocity,
		self:_GetBoidsOptions()
	)

	if hasArrived then
		self:StopMovement(entity)
		return "Success", nil
	end

	local humanoid = self:_GetHumanoid(entity)
	if humanoid == nil then
		self:StopMovement(entity)
		return "Fail", "MissingHumanoid"
	end

	humanoid:Move(moveDirection)
	humanoid.AutoRotate = moveDirection.Magnitude > 0.1
	movementState.PreviousVelocity = moveDirection
	self._enemyEntityFactory:SetPathMoving(entity, true)
	return "Running", nil
end

function MovementService:_TickPath(entity: number, movementState: TPathMovementState): ("Running" | "Success" | "Fail", string?)
	local promise = movementState.Promise
	if promise == nil then
		self:StopMovement(entity)
		return "Fail", "MissingPathPromise"
	end

	local status = promise:getStatus()
	if status == Promise.Status.Started then
		return "Running", nil
	end

	self._movementByEntity[entity] = nil
	self._enemyEntityFactory:SetPathMoving(entity, false)

	if status == Promise.Status.Resolved then
		return "Success", nil
	end

	return "Fail", "PathPromiseRejected"
end

function MovementService:_GetHumanoid(entity: number): Humanoid?
	local modelRef = self._enemyEntityFactory:GetModelRef(entity)
	local model = if modelRef ~= nil then modelRef.Model else nil
	return if model ~= nil then model:FindFirstChildWhichIsA("Humanoid") else nil
end

function MovementService:_StopHumanoid(entity: number)
	local humanoid = self:_GetHumanoid(entity)
	if humanoid ~= nil then
		humanoid:Move(Vector3.zero)
	end
end

return MovementService
