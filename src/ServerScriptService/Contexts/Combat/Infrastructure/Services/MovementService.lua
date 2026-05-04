--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ReplicatedStorage.Utilities.PathfindingHelper)
local BoidsHelper = require(ReplicatedStorage.Utilities.BoidsHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)

local GOAL_POSITION_EPSILON = 0.01

local function xzDisplacement(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

type EnemyMovementMode = EnemyTypes.EnemyMovementMode

type TPathMovementState = {
	Mode: "Path",
	Promise: any,
}

type TBoidsMovementState = {
	Mode: "Boids",
	SessionId: string,
	GoalPosition: Vector3,
	PreviousVelocity: Vector3,
	ComputePromise: any?,
	BoidsReady: boolean,
	ComputeFailedReason: string?,
	JumpMoveToConnection: RBXScriptConnection?,
	JumpMoveToTimeoutToken: number,
	JumpMoveToStuckLastSample: Vector3?,
	JumpMoveToStuckLowMotionTicks: number,
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
end

function MovementService:ConfigureEnemyEntityFactory(enemyEntityFactory: any)
	self._enemyEntityFactory = enemyEntityFactory
end

function MovementService:ConfigureLockOnService(lockOnService: any)
	self._lockOnService = lockOnService
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
		local computePromise = movementState.ComputePromise
		if computePromise ~= nil and type(computePromise.cancel) == "function" then
			computePromise:cancel()
		end
		if movementState.Mode == "Boids" then
			self:_CancelBoidsJumpMoveTo(entity, movementState)
		end
		if movementState.BoidsReady then
			BoidsHelper.CleanupEntity(entity, movementState.SessionId)
		end
		self:_StopHumanoid(entity)
	end

	self._movementByEntity[entity] = nil
	self._enemyEntityFactory:SetPathMoving(entity, false)
	if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
		self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
	end
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
		GetGoalPosition = function(entity: number): Vector3?
			local pathState = self._enemyEntityFactory:GetPathState(entity)
			return if pathState ~= nil then pathState.GoalPosition else nil
		end,
		ComputePathWaypoints = function(entity: number, targetPosition: Vector3): (boolean, { any }?, string?)
			local path = PathfindingHelper.CreatePath(entity, {
				EnemyEntityFactory = self._enemyEntityFactory,
			}, self:_GetAgentParams(entity), CombatMovementConfig.PATHFINDING)
			if path == nil then
				return false, nil, "PathCreateFailed"
			end

			local success, waypoints, reason = PathfindingHelper.ComputeWaypoints(
				path,
				targetPosition,
				entity,
				CombatMovementConfig.PATHFINDING
			)
			path:Destroy()
			return success, waypoints, reason
		end,
	}
end

function MovementService:_GetBoidsMinGroupSize(): number
	local configuredMinGroupSize = BoidsConfig.MinGroupSize
	if type(configuredMinGroupSize) ~= "number" then
		return 2
	end

	return math.max(1, math.floor(configuredMinGroupSize))
end

function MovementService:_BuildBoidsSessionId(goalPosition: Vector3): string
	-- Enough precision that distinct goal vectors are unlikely to share a session (%.2f could merge nearby goals).
	return string.format(
		"CombatAdvanceBase:%.5f:%.5f:%.5f",
		goalPosition.X,
		goalPosition.Y,
		goalPosition.Z
	)
end

function MovementService:_GetEntityModel(entity: number): Model?
	local modelRef = self._enemyEntityFactory:GetModelRef(entity)
	return if modelRef ~= nil then modelRef.Model else nil
end

function MovementService:_ResolveAdvanceMode(
	movementMode: EnemyMovementMode,
	goalPosition: Vector3
): ("Path" | "Boids")?
	if movementMode == "Path" or movementMode == "Boids" then
		return movementMode
	end

	if movementMode == "Any" then
		return if self:_CountBoidsCapableEntitiesAtGoal(goalPosition) >= self:_GetBoidsMinGroupSize() then "Boids" else "Path"
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
	local path = PathfindingHelper.CreatePath(entity, {
		EnemyEntityFactory = self._enemyEntityFactory,
	}, self:_GetAgentParams(entity), CombatMovementConfig.PATHFINDING)
	if path == nil then
		return false
	end

	local sessionId = self:_BuildBoidsSessionId(goalPosition)
	local computePromise =
		PathfindingHelper.ComputeWaypointsPromise(path, goalPosition, entity, CombatMovementConfig.PATHFINDING)

	local movementRecord: TBoidsMovementState = {
		Mode = "Boids",
		SessionId = sessionId,
		GoalPosition = goalPosition,
		PreviousVelocity = Vector3.zero,
		ComputePromise = computePromise,
		BoidsReady = false,
		ComputeFailedReason = nil,
		JumpMoveToConnection = nil,
		JumpMoveToTimeoutToken = 0,
		JumpMoveToStuckLastSample = nil,
		JumpMoveToStuckLowMotionTicks = 0,
	}
	self._movementByEntity[entity] = movementRecord

	computePromise
		:andThen(function(waypoints: { any })
			if self._movementByEntity[entity] ~= movementRecord then
				return
			end
			if movementRecord.ComputePromise ~= computePromise then
				return
			end

			local options = self:_GetBoidsOptions()
			if not BoidsHelper.InitGroupMovementWithWaypoints(entity, sessionId, goalPosition, waypoints, options) then
				movementRecord.ComputeFailedReason = "BoidsInitFailed"
				movementRecord.ComputePromise = nil
				return
			end

			movementRecord.BoidsReady = true
			movementRecord.ComputePromise = nil
		end)
		:catch(function(reason: any)
			if self._movementByEntity[entity] ~= movementRecord then
				return
			end
			if movementRecord.ComputePromise ~= computePromise then
				return
			end

			movementRecord.ComputeFailedReason = if type(reason) == "string" then reason else tostring(reason)
			movementRecord.ComputePromise = nil
		end)

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

function MovementService:_ResetJumpMoveToStuckWatchdog(movementState: TBoidsMovementState)
	movementState.JumpMoveToStuckLastSample = nil
	movementState.JumpMoveToStuckLowMotionTicks = 0
end

function MovementService:_CancelBoidsJumpMoveTo(entity: number, movementState: TBoidsMovementState)
	if movementState.JumpMoveToConnection ~= nil then
		movementState.JumpMoveToConnection:Disconnect()
		movementState.JumpMoveToConnection = nil
	end
	movementState.JumpMoveToTimeoutToken += 1
	self:_ResetJumpMoveToStuckWatchdog(movementState)
	if movementState.BoidsReady then
		BoidsHelper.NotifyJumpMoveToFinished(entity, movementState.SessionId)
	end
end

function MovementService:_OnBoidsJumpMoveToFinished(
	entity: number,
	movementState: TBoidsMovementState,
	_humanoid: Humanoid,
	_reached: boolean
)
	if self._movementByEntity[entity] ~= movementState then
		return
	end
	if movementState.Mode ~= "Boids" then
		return
	end
	if movementState.JumpMoveToConnection ~= nil then
		movementState.JumpMoveToConnection:Disconnect()
		movementState.JumpMoveToConnection = nil
	end
	movementState.JumpMoveToTimeoutToken += 1
	if movementState.BoidsReady then
		BoidsHelper.NotifyJumpMoveToFinished(entity, movementState.SessionId)
	end
	self:_ResetJumpMoveToStuckWatchdog(movementState)
end

function MovementService:_BeginBoidsJumpMoveTo(
	entity: number,
	movementState: TBoidsMovementState,
	humanoid: Humanoid,
	jumpTarget: Vector3
)
	self:_CancelBoidsJumpMoveTo(entity, movementState)

	self:_TryJumpHumanoid(humanoid)
	humanoid:MoveTo(jumpTarget)

	if movementState.BoidsReady then
		BoidsHelper.NotifyJumpMoveToStarted(entity, movementState.SessionId)
	end

	movementState.JumpMoveToTimeoutToken += 1
	local scheduleToken = movementState.JumpMoveToTimeoutToken
	local timeoutSeconds = BoidsConfig.JumpMoveToTimeoutSeconds
	if type(timeoutSeconds) == "number" and timeoutSeconds > 0 then
		task.delay(timeoutSeconds, function()
			local current = self._movementByEntity[entity]
			if current ~= movementState then
				return
			end
			if movementState.Mode ~= "Boids" then
				return
			end
			if movementState.JumpMoveToTimeoutToken ~= scheduleToken then
				return
			end
			if movementState.JumpMoveToConnection == nil then
				return
			end
			self:_OnBoidsJumpMoveToFinished(entity, movementState, humanoid, false)
		end)
	end

	movementState.JumpMoveToConnection = humanoid.MoveToFinished:Connect(function(reached: boolean)
		self:_OnBoidsJumpMoveToFinished(entity, movementState, humanoid, reached)
	end)

	local model = self:_GetEntityModel(entity)
	local primaryPart = if model ~= nil then model.PrimaryPart else nil
	if primaryPart ~= nil then
		movementState.JumpMoveToStuckLastSample = primaryPart.Position
	else
		movementState.JumpMoveToStuckLastSample = nil
	end
	movementState.JumpMoveToStuckLowMotionTicks = 0
end

function MovementService:_TickBoids(entity: number, movementState: TBoidsMovementState): ("Running" | "Success" | "Fail", string?)
	if movementState.ComputeFailedReason ~= nil then
		self:StopMovement(entity)
		return "Fail", movementState.ComputeFailedReason
	end

	if not movementState.BoidsReady then
		if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
		end
		local humanoid = self:_GetHumanoid(entity)
		if humanoid == nil then
			self:StopMovement(entity)
			return "Fail", "MissingHumanoid"
		end
		humanoid:Move(Vector3.zero)
		self._enemyEntityFactory:SetPathMoving(entity, true)
		return "Running", nil
	end

	if movementState.JumpMoveToConnection ~= nil then
		if BoidsConfig.JumpMoveToStuckEnabled ~= false then
			local epsilon = BoidsConfig.JumpMoveToStuckEpsilonStuds
			if type(epsilon) ~= "number" or epsilon <= 0 then
				epsilon = 0.15
			end
			local minTicks = BoidsConfig.JumpMoveToStuckMinTicks
			if type(minTicks) ~= "number" or minTicks < 1 then
				minTicks = 4
			end
			local humanoidForStuck = self:_GetHumanoid(entity)
			local model = self:_GetEntityModel(entity)
			local primaryPart = if model ~= nil then model.PrimaryPart else nil
			local pos = if primaryPart ~= nil then primaryPart.Position else nil
			if humanoidForStuck ~= nil and pos ~= nil then
				local lastSample = movementState.JumpMoveToStuckLastSample
				if lastSample == nil then
					movementState.JumpMoveToStuckLastSample = pos
					movementState.JumpMoveToStuckLowMotionTicks = 0
				else
					local delta = xzDisplacement(pos, lastSample)
					if delta < epsilon then
						movementState.JumpMoveToStuckLowMotionTicks += 1
						if movementState.JumpMoveToStuckLowMotionTicks >= minTicks then
							self:_OnBoidsJumpMoveToFinished(entity, movementState, humanoidForStuck, false)
						end
					else
						movementState.JumpMoveToStuckLowMotionTicks = 0
						movementState.JumpMoveToStuckLastSample = pos
					end
				end
			end
		end
		self._enemyEntityFactory:SetPathMoving(entity, true)
		return "Running", nil
	end

	local moveDirection, hasArrived, shouldJump, facingFlatForward, jumpMoveToWorld = BoidsHelper.TickEntity(
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

	if jumpMoveToWorld ~= nil then
		self:_BeginBoidsJumpMoveTo(entity, movementState, humanoid, jumpMoveToWorld)
		self._enemyEntityFactory:SetPathMoving(entity, true)
		if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			self._lockOnService:SetBoidsFacingFlatForward(entity, facingFlatForward)
			if type(self._lockOnService.UpdateAll) == "function" then
				self._lockOnService:UpdateAll({ entity })
			end
		end
		return "Running", nil
	end

	if shouldJump then
		self:_TryJumpHumanoid(humanoid)
	end
	humanoid:Move(moveDirection)
	movementState.PreviousVelocity = moveDirection
	self._enemyEntityFactory:SetPathMoving(entity, true)
	if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
		self._lockOnService:SetBoidsFacingFlatForward(entity, facingFlatForward)
		if type(self._lockOnService.UpdateAll) == "function" then
			self._lockOnService:UpdateAll({ entity })
		end
	end
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
	local model = self:_GetEntityModel(entity)
	return if model ~= nil then model:FindFirstChildWhichIsA("Humanoid") else nil
end

function MovementService:_StopHumanoid(entity: number)
	local humanoid = self:_GetHumanoid(entity)
	if humanoid ~= nil then
		humanoid:Move(Vector3.zero)
	end
end

function MovementService:_TryJumpHumanoid(humanoid: Humanoid)
	local humanoidState = humanoid:GetState()
	if humanoidState == Enum.HumanoidStateType.Jumping or humanoidState == Enum.HumanoidStateType.Freefall then
		return
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

return MovementService
