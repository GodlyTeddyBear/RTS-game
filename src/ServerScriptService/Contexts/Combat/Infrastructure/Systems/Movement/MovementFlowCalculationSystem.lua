--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local PathfindingHelper = require(ServerStorage.Utilities.PathfindingHelper)

local MovementFlowCalculationSystem = {}
MovementFlowCalculationSystem.__index = MovementFlowCalculationSystem

local function isFiniteVector3(value: Vector3): boolean
	return value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < math.huge
		and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

function MovementFlowCalculationSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementFlowCalculationSystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	self._actorReadService = dependencies.ActorReadService
	self._flowfieldService = dependencies.FlowfieldService
	self._flowDispatchService = dependencies.FlowDispatchService
	self._flowSnapshotService = dependencies.FlowSnapshotService
	self._pathRuntimeService = dependencies.PathRuntimeService
	self._publishedVelocityByEntity = {}
	self._previousVelocityByEntity = {}
	self._tickId = 0
	return self
end

function MovementFlowCalculationSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.FlowGridState [AUTHORITATIVE]
	-- WRITES: Movement.PathRuntimeState [AUTHORITATIVE], Movement.FlowCalculationState [AUTHORITATIVE], Movement.ApplyState [AUTHORITATIVE]
	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "MoveIntent" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	self._tickId += 1
	local published = self._flowDispatchService:Poll()
	if published ~= nil then
		self._publishedVelocityByEntity = published
	end
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
	self:_DispatchFlowSeparation(queryResult.value)
end

function MovementFlowCalculationSystem:_RunEntity(entity: number, now: number)
	local intent = self:_Get(entity, "MoveIntent", "Movement")
	local requestedAt = if type(intent) == "table" and type(intent.RequestedAt) == "number" then intent.RequestedAt else now
	local goalPosition = if type(intent) == "table" then intent.GoalPosition else nil
	local requestedMode = if type(intent) == "table" then intent.MovementMode else nil
	if type(intent) ~= "table" or intent.Status == "Cancelled" then
		self:_WriteApplyState(entity, requestedAt, now, "Cancelled", nil, nil, false, "MovementCancelled")
		return
	end
	if typeof(goalPosition) ~= "Vector3" or type(requestedMode) ~= "string" then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, "InvalidMoveIntent")
		return
	end
	if not isFiniteVector3(goalPosition) then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, "InvalidGoalPosition")
		return
	end

	local resolvedGoalPosition, goalResolutionReason = self:_ResolveGoalPosition(entity, goalPosition, requestedAt)

	local mode = self:_ResolveMode(requestedMode, resolvedGoalPosition)
	if mode == "Path" then
		self:_CalculatePath(entity, goalPosition, resolvedGoalPosition, requestedAt, now, goalResolutionReason)
		return
	end
	if mode == "Boids" then
		self:_CalculateFlow(entity, goalPosition, resolvedGoalPosition, requestedAt, now, goalResolutionReason)
		return
	end
	if mode == "Direct" then
		self:_CalculateDirect(entity, goalPosition, resolvedGoalPosition, requestedAt, now, goalResolutionReason)
		return
	end
	self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, "InvalidMovementMode")
end

function MovementFlowCalculationSystem:_CalculateDirect(
	entity: number,
	originalGoalPosition: Vector3,
	goalPosition: Vector3,
	requestedAt: number,
	now: number,
	goalResolutionReason: string?
)
	local position = self._actorReadService:GetPosition(self._entityFactory, self._entityContext, entity)
	local profile = self._actorReadService:GetActorProfile(self._entityFactory, entity)
	if position == nil then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, "MissingActorPosition")
		return
	end
	local reachedDistance = if type(profile) == "table" and type(profile.GoalReachedDistance) == "number" then profile.GoalReachedDistance else 4
	local isDone = self:_GetGoalDistance(profile, position, goalPosition) <= reachedDistance
	self:_WriteRuntimeState(entity, "Direct", originalGoalPosition, goalPosition, goalResolutionReason, requestedAt, now, if isDone then "Done" else "Running", nil)
	self:_WriteApplyState(entity, requestedAt, now, if isDone then "Done" else "Running", goalPosition, nil, not isDone, nil)
end

function MovementFlowCalculationSystem:_CalculatePath(
	entity: number,
	originalGoalPosition: Vector3,
	goalPosition: Vector3,
	requestedAt: number,
	now: number,
	goalResolutionReason: string?
)
	local started, reason = self._pathRuntimeService:StartOrRetarget(self._entityFactory, entity, goalPosition)
	if not started then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, reason or "PathStartFailed")
		return
	end
	local status, pollReason = self._pathRuntimeService:Poll(entity)
	self:_WriteRuntimeState(entity, "Path", originalGoalPosition, goalPosition, goalResolutionReason, requestedAt, now, status, pollReason)
	self:_WriteApplyState(entity, requestedAt, now, status, nil, nil, status == "Running", pollReason)
end

function MovementFlowCalculationSystem:_CalculateFlow(
	entity: number,
	originalGoalPosition: Vector3,
	goalPosition: Vector3,
	requestedAt: number,
	now: number,
	goalResolutionReason: string?
)
	local position = self._actorReadService:GetPosition(self._entityFactory, self._entityContext, entity)
	if position == nil then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, "MissingActorPosition")
		return
	end

	local _attachment, attachReason = self._flowfieldService:Attach(entity, goalPosition)
	if attachReason ~= nil then
		self:_WriteApplyState(entity, requestedAt, now, "Failed", nil, nil, false, attachReason)
		return
	end

	local velocityXZ = self._publishedVelocityByEntity[entity] or self._flowfieldService:Sample(entity, position)
	if velocityXZ ~= nil then
		self._previousVelocityByEntity[entity] = velocityXZ
	end
	local profile = self._actorReadService:GetActorProfile(self._entityFactory, entity)
	local reachedDistance = if type(profile) == "table" and type(profile.GoalReachedDistance) == "number" then profile.GoalReachedDistance else 4
	if self:_GetGoalDistance(profile, position, goalPosition) <= reachedDistance then
		self:_WriteRuntimeState(entity, "Boids", originalGoalPosition, goalPosition, goalResolutionReason, requestedAt, now, "Done", nil)
		self:_WriteApplyState(entity, requestedAt, now, "Done", nil, nil, false, nil)
		return
	end
	local targetPosition = if velocityXZ ~= nil and velocityXZ.Magnitude > 0
		then self._flowfieldService:SanitizeTarget(position + Vector3.new(velocityXZ.X, 0, velocityXZ.Y) * 4)
		else nil
	self:_WriteRuntimeState(entity, "Boids", originalGoalPosition, goalPosition, goalResolutionReason, requestedAt, now, "Running", nil)
	self:_WriteApplyState(entity, requestedAt, now, "Running", targetPosition, velocityXZ, targetPosition ~= nil, nil)
end

function MovementFlowCalculationSystem:_DispatchFlowSeparation(entities: { number })
	local config = CombatMovementConfig.FLOW_SOFT_SEPARATION
	if config == nil or config.Enabled ~= true or config.ParallelEnabled ~= true then return end
	local _pathfinder, mapping = self._flowfieldService:GetRuntime()
	if mapping == nil then return end
	local wallGrid, wallGridHalfSize, wallGridWidth = self._flowSnapshotService:BuildWallGridSnapshot()
	local actorIds, goalKeys = {}, {}
	local flatPositionX, flatPositionY, radius = {}, {}, {}
	local flowVelocityX, flowVelocityY, previousVelocityX, previousVelocityY = {}, {}, {}, {}
	local walkSpeed, velAlpha, isSettled = {}, {}, {}
	for _, entity in ipairs(entities) do
		local intent = self:_Get(entity, "MoveIntent", "Movement")
		local runtime = self:_Get(entity, "PathRuntimeState", "Movement")
		if type(intent) ~= "table" or type(runtime) ~= "table" or runtime.Mode ~= "Boids" then continue end
		local goalPosition = runtime.ResolvedGoalPosition or runtime.GoalPosition
		local position = self._actorReadService:GetPosition(self._entityFactory, self._entityContext, entity)
		if typeof(goalPosition) ~= "Vector3" or position == nil then continue end
		local attachment = self._flowfieldService:Attach(entity, goalPosition)
		local flowVelocity = self._flowfieldService:Sample(entity, position) or Vector2.zero
		local previousVelocity = self._previousVelocityByEntity[entity] or flowVelocity
		local profile = self._actorReadService:GetActorProfile(self._entityFactory, entity)
		local agentParams = if type(profile) == "table" then profile.AgentParams else nil
		actorIds[#actorIds + 1] = entity
		goalKeys[#goalKeys + 1] = if type(attachment) == "table" then attachment.GoalKey else tostring(goalPosition)
		flatPositionX[#flatPositionX + 1] = position.X
		flatPositionY[#flatPositionY + 1] = position.Z
		radius[#radius + 1] = if type(agentParams) == "table" and type(agentParams.AgentRadius) == "number" then agentParams.AgentRadius else 2
		flowVelocityX[#flowVelocityX + 1] = flowVelocity.X
		flowVelocityY[#flowVelocityY + 1] = flowVelocity.Y
		previousVelocityX[#previousVelocityX + 1] = previousVelocity.X
		previousVelocityY[#previousVelocityY + 1] = previousVelocity.Y
		walkSpeed[#walkSpeed + 1] = self._actorReadService:GetCurrentMoveSpeed(self._entityFactory, entity)
		velAlpha[#velAlpha + 1] = if type(config.VelAlpha) == "number" then config.VelAlpha else 0.15
		isSettled[#isSettled + 1] = false
	end
	if #actorIds == 0 then return end
	self._flowDispatchService:Dispatch({
		ActorIds = actorIds,
		SharedMemory = {
			Scalars = {
				CellWidthStuds = mapping.CellWidthStuds,
				OriginX = mapping.OriginWorld.X,
				OriginY = mapping.OriginWorld.Z,
				WallGridHalfSize = wallGridHalfSize,
				WallGridWidth = wallGridWidth,
				KForce = config.KForce or 80,
				MinSeparationDistance = config.MinSeparationDistance or 1e-4,
				AggregateCellMinMembers = config.AggregateCellMinMembers or 4,
				AggregateForceScale = config.AggregateForceScale or 1,
				AggregateInfluenceRadiusMultiplier = config.AggregateInfluenceRadiusMultiplier or 1,
				WallCollisionEnabled = config.WallCollisionEnabled == true,
				WallCollisionAxisClampEnabled = config.WallCollisionAxisClampEnabled ~= false,
				WallCollisionCornerClampEnabled = config.WallCollisionCornerClampEnabled ~= false,
				WallCollisionUseUnitRadiusPadding = config.WallCollisionUseUnitRadiusPadding == true,
				WallCollisionCellProbePaddingStuds = config.WallCollisionCellProbePaddingStuds or 0,
				WallCollisionVelocityEpsilon = config.WallCollisionVelocityEpsilon or 1e-4,
				ClumpTouchPaddingStuds = config.ClumpTouchDistancePaddingStuds or 0,
			},
			Arrays = { WallGrid = wallGrid },
		},
		ManagerPayload = {
			TickId = self._tickId, EntityIds = actorIds, GoalKeys = goalKeys,
			FlatPositionX = flatPositionX, FlatPositionY = flatPositionY, Radius = radius,
			FlowVelocityX = flowVelocityX, FlowVelocityY = flowVelocityY,
			PreviousVelocityX = previousVelocityX, PreviousVelocityY = previousVelocityY,
			WalkSpeed = walkSpeed, VelAlpha = velAlpha, IsSettled = isSettled, DeltaTime = 1 / 60,
			CellWidthStuds = mapping.CellWidthStuds, OriginX = mapping.OriginWorld.X, OriginY = mapping.OriginWorld.Z,
			WallGridHalfSize = wallGridHalfSize, WallGridWidth = wallGridWidth, WallGrid = wallGrid,
			KForce = config.KForce or 80, MinSeparationDistance = config.MinSeparationDistance or 1e-4,
			AggregateCellMinMembers = config.AggregateCellMinMembers or 4, AggregateForceScale = config.AggregateForceScale or 1,
			AggregateInfluenceRadiusMultiplier = config.AggregateInfluenceRadiusMultiplier or 1,
			WallCollisionEnabled = config.WallCollisionEnabled == true, WallCollisionAxisClampEnabled = config.WallCollisionAxisClampEnabled ~= false,
			WallCollisionCornerClampEnabled = config.WallCollisionCornerClampEnabled ~= false,
			WallCollisionUseUnitRadiusPadding = config.WallCollisionUseUnitRadiusPadding == true,
			WallCollisionCellProbePaddingStuds = config.WallCollisionCellProbePaddingStuds or 0,
			WallCollisionVelocityEpsilon = config.WallCollisionVelocityEpsilon or 1e-4,
			ClumpTouchPaddingStuds = config.ClumpTouchDistancePaddingStuds or 0,
		},
		RunRequest = { Args = { TickId = self._tickId }, BatchSize = config.ParallelVelocityBatchSize or 16 },
	})
end

function MovementFlowCalculationSystem:_ResolveGoalPosition(
	entity: number,
	goalPosition: Vector3,
	requestedAt: number
): (Vector3, string?)
	local profile = self._actorReadService:GetActorProfile(self._entityFactory, entity)
	if type(profile) ~= "table" or profile.GroundGoals ~= true then
		return goalPosition, nil
	end

	local runtime = self:_Get(entity, "PathRuntimeState", "Movement")
	if type(runtime) == "table"
		and runtime.RequestedAt == requestedAt
		and runtime.OriginalGoalPosition == goalPosition
		and typeof(runtime.ResolvedGoalPosition) == "Vector3"
	then
		return runtime.ResolvedGoalPosition, runtime.GoalResolutionReason
	end

	local options = table.clone(CombatMovementConfig.GOAL_NORMALIZATION)
	local entityRuntime = workspace:FindFirstChild("EntityRuntime")
	if entityRuntime ~= nil then
		options.ExcludeInstances = { entityRuntime }
	end
	local resolved = PathfindingHelper.NormalizeGroundTarget(goalPosition, options)
	if typeof(resolved) == "Vector3" and isFiniteVector3(resolved) then
		return resolved, nil
	end
	return goalPosition, "GroundNormalizationFallback"
end

function MovementFlowCalculationSystem:_GetGoalDistance(profile: any, position: Vector3, goalPosition: Vector3): number
	if type(profile) == "table" and profile.GoalDistanceMode == "Horizontal" then
		return (Vector2.new(goalPosition.X, goalPosition.Z) - Vector2.new(position.X, position.Z)).Magnitude
	end
	return (goalPosition - position).Magnitude
end

function MovementFlowCalculationSystem:_ResolveMode(requestedMode: string, goalPosition: Vector3): string?
	if requestedMode == "Path" or requestedMode == "Boids" or requestedMode == "Direct" then
		return requestedMode
	end
	if requestedMode ~= "Any" then
		return nil
	end
	return if self._actorReadService:CountFlowEligiblePeers(self._entityFactory, goalPosition) >= 2 then "Boids" else "Path"
end

function MovementFlowCalculationSystem:_WriteRuntimeState(
	entity: number,
	mode: string,
	originalGoalPosition: Vector3,
	goalPosition: Vector3,
	goalResolutionReason: string?,
	requestedAt: number,
	now: number,
	status: string,
	reason: string?
)
	self._entityFactory:Set(entity, "PathRuntimeState", {
		Mode = mode,
		GoalPosition = goalPosition,
		OriginalGoalPosition = originalGoalPosition,
		ResolvedGoalPosition = goalPosition,
		GoalResolutionReason = goalResolutionReason,
		RequestedAt = requestedAt,
		StartedAt = now,
		UpdatedAt = now,
		Status = status,
		FailureReason = reason,
	}, "Movement")
	self._entityFactory:Set(entity, "FlowCalculationState", {
		RequestedAt = requestedAt,
		UpdatedAt = now,
		Status = status,
		IsDone = status == "Done",
		FailureReason = reason,
	}, "Movement")
end

function MovementFlowCalculationSystem:_WriteApplyState(
	entity: number,
	requestedAt: number,
	now: number,
	status: string,
	targetPosition: Vector3?,
	velocityXZ: Vector2?,
	isMoving: boolean,
	reason: string?
)
	self._entityFactory:Set(entity, "ApplyState", {
		RequestedAt = requestedAt,
		UpdatedAt = now,
		Status = status,
		TargetPosition = targetPosition,
		VelocityXZ = velocityXZ,
		IsMoving = isMoving,
		IsDone = status == "Done",
		FailureReason = reason,
	}, "Movement")
end

function MovementFlowCalculationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementFlowCalculationSystem
