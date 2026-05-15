--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ReplicatedStorage.Utilities.PathfindingHelper)
local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)

local GOAL_POSITION_EPSILON = 0.01
local FLOW_SEPARATION_MATERIAL_MOVE_RATIO = 0.25

local function _ZigZagEncodeInt(value: number): number
	return if value >= 0 then value * 2 else -value * 2 - 1
end

local function _PackedSeparationCellKey(gx: number, gz: number): number
	local x = _ZigZagEncodeInt(gx)
	local z = _ZigZagEncodeInt(gz)
	local sum = x + z
	return sum * (sum + 1) / 2 + z
end

local function _FlowGoalKey(cell: Vector2): string
	return string.format("%d,%d", cell.X, cell.Y)
end

local function _ClampVector2Magnitude(vec: Vector2, maxMagnitude: number): Vector2
	if maxMagnitude <= 0 then
		return Vector2.zero
	end

	local magnitude = vec.Magnitude
	if magnitude > maxMagnitude then
		return vec * (maxMagnitude / magnitude)
	end

	return vec
end

local function _FlatXZ(worldPosition: Vector3): Vector2
	return Vector2.new(worldPosition.X, worldPosition.Z)
end

local function _XZDistance(a: Vector3, b: Vector3): number
	return (_FlatXZ(a) - _FlatXZ(b)).Magnitude
end

local function _ForEachCoveredSeparationCell(
	flatPosition: Vector2,
	radius: number,
	cellWidthStuds: number,
	callback: (number, number) -> ()
)
	if cellWidthStuds <= 0 then
		return
	end

	local offset = Vector2.new(radius, radius)
	local corner0X = math.round((flatPosition.X - offset.X) / cellWidthStuds)
	local corner0Z = math.round((flatPosition.Y - offset.Y) / cellWidthStuds)
	local corner1X = math.round((flatPosition.X + offset.X) / cellWidthStuds)
	local corner1Z = math.round((flatPosition.Y + offset.Y) / cellWidthStuds)
	local minGx = math.min(corner0X, corner1X)
	local maxGx = math.max(corner0X, corner1X)
	local minGz = math.min(corner0Z, corner1Z)
	local maxGz = math.max(corner0Z, corner1Z)

	for gx = minGx, maxGx do
		for gz = minGz, maxGz do
			callback(gx, gz)
		end
	end
end

type EnemyMovementMode = EnemyTypes.EnemyMovementMode

type TPathMovementState = {
	Mode: "Path",
	Promise: any,
}

type TFlowMovementState = {
	Mode: "Flow",
	GoalSnapshot: Vector3,
	GoalKey: string,
	GoalWorldSample: Vector3,
}

type TMovementState = TPathMovementState | TFlowMovementState

type TAdvanceStatus = "Running" | "Success" | "Fail"

type TAdvanceFrameResult = {
	Status: TAdvanceStatus,
	Reason: string?,
	FrameId: number,
}

type TSharedFlowfieldEntry = {
	Flowfield: any,
	GoalCell: Vector2,
	GoalWorldSample: Vector3,
	LastRefreshClock: number,
	RefreshInProgress: boolean,
	RefCount: number,
}

type TFlowSeparationCoveredCell = {
	Key: number,
	Gx: number,
	Gz: number,
}

type TFlowSeparationEntityState = {
	Position: Vector3?,
	FlatPosition: Vector2?,
	Radius: number,
	GoalKey: string?,
	Settled: boolean,
	Active: boolean,
	CoveredCells: { TFlowSeparationCoveredCell },
	Separation: Vector2,
	NearGoalScale: number,
	LastSpatialRefreshFlatPosition: Vector2?,
	IsInsideNearGoalBand: boolean,
	LastGoalKey: string?,
	LastDirtyMarkFlatPosition: Vector2?,
}

type TFlowSeparationRuntime = {
	SessionUserId: number?,
	CurrentTime: number?,
	CellWidthStuds: number,
	EntityStateById: { [number]: TFlowSeparationEntityState },
	BucketsByCell: { [number]: { [number]: boolean } },
	DirtyEntities: { [number]: boolean },
	DirtyCells: { [number]: boolean },
	TrackedFlowEntities: { [number]: boolean },
	ActiveFlowEntities: { [number]: boolean },
	ActiveSolveEntities: { [number]: boolean },
}

type TFastFlowProfileCounters = {
	SharedFieldCreations: number,
	SharedFieldRefreshes: number,
	MergeAttempts: number,
	TrackedFlowEntities: number,
	ActiveSeparationEntities: number,
	DenseCellsEncountered: number,
	DenseCellFallbackActivations: number,
	DirtyEntitiesProcessed: number,
	DirtyCellsProcessed: number,
	LocalPairSolves: number,
	BucketMembershipUpdates: number,
	CachedRootPartHits: number,
	CachedRootPartMisses: number,
	CachedHumanoidHits: number,
	CachedHumanoidMisses: number,
	SpatialRefreshCalls: number,
	CoveredCellRecomputes: number,
	NearGoalBandRecomputes: number,
	DirtyMarksTriggered: number,
	DirtyMarksSkipped: number,
}

type TFlowActorRefs = {
	Model: Model?,
	RootPart: BasePart?,
	Humanoid: Humanoid?,
	LastWalkSpeed: number?,
}

--[=[
	@class MovementService
	Owns Combat enemy movement runtime coordination for pathfinding- and flowfield-based advance.
	@server
]=]
local MovementService = {}
MovementService.__index = MovementService

function MovementService.new()
	local self = setmetatable({}, MovementService)
	self._movementByEntity = {} :: { [number]: TMovementState }
	self._advanceFrameResultByEntity = {} :: { [number]: TAdvanceFrameResult }
	self._movementFrameId = 0
	self._fastFlowPathfinder = nil
	self._fastFlowMapping = nil
	self._lastFastFlowEndpointDiagnosticKey = nil :: string?
	self._flowVelByEntity = {} :: { [number]: Vector2 }
	self._flowSteeringRepairAtClockByEntity = {} :: { [number]: number }
	self._flowSeparationRuntime = nil :: TFlowSeparationRuntime?
	self._sharedFlowfieldsByGoalKey = {} :: { [string]: TSharedFlowfieldEntry }
	self._flowGoalKeyByEntity = {} :: { [number]: string }
	self._activeFlowEntitiesByGoalKey = {} :: { [string]: { [number]: boolean } }
	self._flowSettledByEntity = {} :: { [number]: boolean }
	self._flowSettleAnchorGoalKeyByEntity = {} :: { [number]: string }
	self._flowActorRefsByEntity = {} :: { [number]: TFlowActorRefs }
	self._fastFlowProfileCounters = nil :: TFastFlowProfileCounters?
	self._lastFastFlowProfileLogAt = 0
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

function MovementService:ConfigureFastFlow(pathfinder: any?, mapping: FastFlowHelper.TFlowGridMapping?)
	self._fastFlowPathfinder = pathfinder
	self._fastFlowMapping = mapping
end

function MovementService:ResetFastFlowRuntime()
	table.clear(self._flowVelByEntity)
	table.clear(self._flowSteeringRepairAtClockByEntity)
	table.clear(self._sharedFlowfieldsByGoalKey)
	table.clear(self._flowGoalKeyByEntity)
	table.clear(self._activeFlowEntitiesByGoalKey)
	table.clear(self._flowSettledByEntity)
	table.clear(self._flowSettleAnchorGoalKeyByEntity)
	self._flowSeparationRuntime = nil
	self._lastFastFlowEndpointDiagnosticKey = nil
end

function MovementService:ConfigureFlowfieldDebugRenderer(renderer: ((any, FastFlowHelper.TFlowGridMapping, Vector3) -> ())?)
	self._flowfieldDebugRenderer = renderer
end

function MovementService:BeginCombatFrame(sessionUserId: number, currentTime: number)
	local separationRuntime = self:_GetOrCreateFlowSeparationRuntime()
	separationRuntime.SessionUserId = sessionUserId
	separationRuntime.CurrentTime = currentTime
	self:_ResetFastFlowProfileCounters()
end

function MovementService:EndCombatFrame(_sessionUserId: number)
	self:_EmitFastFlowProfileCounters()
	self._fastFlowProfileCounters = nil
end

function MovementService:TickMovementFrame(_dt: number)
	self._movementFrameId += 1

	if next(self._movementByEntity) == nil then
		return
	end

	local activeEntities = {}
	for entity in self._movementByEntity do
		table.insert(activeEntities, entity)
	end

	for _, entity in ipairs(activeEntities) do
		local status, reason = self:TickAdvance(entity)
		self._advanceFrameResultByEntity[entity] = {
			Status = status,
			Reason = reason,
			FrameId = self._movementFrameId,
		}
	end
end

function MovementService:GetAdvanceStatus(entity: number): (TAdvanceStatus, string?)
	local frameResult = self._advanceFrameResultByEntity[entity]
	if frameResult ~= nil and frameResult.FrameId == self._movementFrameId then
		return frameResult.Status, frameResult.Reason
	end

	if self._movementByEntity[entity] ~= nil then
		return "Running", nil
	end

	return "Fail", "MissingMovementState"
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

	if resolvedMode == "Flow" then
		local startedFlow, flowReason = self:_StartFlow(entity, pathState.GoalPosition)
		if startedFlow then
			return true, nil
		end
		if movementMode ~= "Any" or flowReason ~= "FastFlowNotConfigured" then
			return false, if flowReason ~= nil then flowReason else "FlowStartFailed"
		end
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

	if movementState.Mode == "Flow" then
		return self:_TickFlow(entity, movementState)
	end

	self:_ApplyCurrentMoveSpeed(entity)

	return self:_TickPath(entity, movementState)
end

function MovementService:StopMovement(entity: number)
	local movementState = self._movementByEntity[entity]
	if movementState == nil and self._flowSettleAnchorGoalKeyByEntity[entity] == nil then
		self._advanceFrameResultByEntity[entity] = nil
		return
	end

	if movementState ~= nil then
		if movementState.Mode == "Path" then
			local promise = movementState.Promise
			if promise ~= nil and type(promise.cancel) == "function" then
				promise:cancel()
			end
		else
			self:_StopHumanoid(entity)
		end
	end

	self._advanceFrameResultByEntity[entity] = nil
	self:_ClearMovementRuntimeState(entity)
end

function MovementService:CleanupAll()
	local entities = {}
	for entityId in self._movementByEntity do
		table.insert(entities, entityId)
	end

	for entityId in self._flowSettleAnchorGoalKeyByEntity do
		if self._movementByEntity[entityId] == nil then
			table.insert(entities, entityId)
		end
	end

	for _, entityId in ipairs(entities) do
		self:StopMovement(entityId)
	end

	table.clear(self._flowVelByEntity)
	table.clear(self._flowSteeringRepairAtClockByEntity)
	table.clear(self._sharedFlowfieldsByGoalKey)
	table.clear(self._flowGoalKeyByEntity)
	table.clear(self._activeFlowEntitiesByGoalKey)
	table.clear(self._flowSettledByEntity)
	table.clear(self._flowSettleAnchorGoalKeyByEntity)
	table.clear(self._flowActorRefsByEntity)
	table.clear(self._advanceFrameResultByEntity)
	self._flowSeparationRuntime = nil
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

function MovementService:_GetMinGroupSize(): number
	local configuredMinGroupSize = BoidsConfig.MinGroupSize
	if type(configuredMinGroupSize) ~= "number" then
		return 2
	end

	return math.max(1, math.floor(configuredMinGroupSize))
end

function MovementService:_CanEntityUseFlowAtGoal(entity: number, goalPosition: Vector3): boolean
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

function MovementService:_CountFlowEligibleAtGoal(goalPosition: Vector3): number
	local groupSize = 0
	for _, aliveEntity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
		if self:_CanEntityUseFlowAtGoal(aliveEntity, goalPosition) then
			groupSize += 1
		end
	end
	return groupSize
end

function MovementService:_ResolveAdvanceMode(movementMode: EnemyMovementMode, goalPosition: Vector3): ("Path" | "Flow")?
	if movementMode == "Path" then
		return "Path"
	end

	if movementMode == "Boids" then
		return "Flow"
	end

	if movementMode == "Any" then
		return if self:_CountFlowEligibleAtGoal(goalPosition) >= self:_GetMinGroupSize() then "Flow" else "Path"
	end

	return nil
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

function MovementService:_GetOrCreateFlowActorRefs(entity: number): TFlowActorRefs
	local refs = self._flowActorRefsByEntity[entity]
	if refs == nil then
		refs = {
			Model = nil,
			RootPart = nil,
			Humanoid = nil,
			LastWalkSpeed = nil,
		}
		self._flowActorRefsByEntity[entity] = refs
	end
	return refs
end

function MovementService:_InvalidateFlowActorRefs(entity: number)
	self._flowActorRefsByEntity[entity] = nil
end

function MovementService:_GetEntityModel(entity: number): Model?
	local refs = self:_GetOrCreateFlowActorRefs(entity)
	local modelRef = self._enemyEntityFactory:GetModelRef(entity)
	local resolvedModel = if modelRef ~= nil then modelRef.Model else nil
	if refs.Model ~= resolvedModel then
		refs.Model = resolvedModel
		refs.RootPart = nil
		refs.Humanoid = nil
	end
	if resolvedModel == nil then
		refs.RootPart = nil
		refs.Humanoid = nil
	end
	return resolvedModel
end

function MovementService:_GetEntityRootPart(entity: number): BasePart?
	local refs = self:_GetOrCreateFlowActorRefs(entity)
	local rootPart = refs.RootPart
	local model = refs.Model
	if rootPart ~= nil and rootPart.Parent ~= nil and model ~= nil and rootPart:IsDescendantOf(model) then
		self:_IncrementFastFlowProfileCounter("CachedRootPartHits")
		return rootPart
	end

	self:_IncrementFastFlowProfileCounter("CachedRootPartMisses")
	model = self:_GetEntityModel(entity)
	rootPart = if model ~= nil then model.PrimaryPart else nil
	refs.RootPart = rootPart
	return rootPart
end

function MovementService:_GetEntityPosition(entity: number): Vector3?
	local rootPart = self:_GetEntityRootPart(entity)
	return if rootPart ~= nil then rootPart.Position else nil
end

function MovementService:_GetHumanoid(entity: number): Humanoid?
	local refs = self:_GetOrCreateFlowActorRefs(entity)
	local humanoid = refs.Humanoid
	local model = refs.Model
	if humanoid ~= nil and humanoid.Parent ~= nil and model ~= nil and humanoid:IsDescendantOf(model) then
		self:_IncrementFastFlowProfileCounter("CachedHumanoidHits")
		return humanoid
	end

	self:_IncrementFastFlowProfileCounter("CachedHumanoidMisses")
	model = self:_GetEntityModel(entity)
	humanoid = if model ~= nil then model:FindFirstChildWhichIsA("Humanoid") else nil
	refs.Humanoid = humanoid
	return humanoid
end

function MovementService:_GetWalkSpeedWriteEpsilon(sepConfig: any): number
	local configuredEpsilon = if sepConfig ~= nil then sepConfig.WalkSpeedWriteEpsilon else nil
	if type(configuredEpsilon) == "number" and configuredEpsilon >= 0 then
		return configuredEpsilon
	end
	return 0.05
end

function MovementService:_ApplyCurrentMoveSpeed(entity: number, sepConfig: any?): number
	local humanoid = self:_GetHumanoid(entity)
	local refs = self:_GetOrCreateFlowActorRefs(entity)
	local currentMoveSpeed = nil
	if self._enemyEntityFactory ~= nil and type(self._enemyEntityFactory.GetCurrentMoveSpeed) == "function" then
		currentMoveSpeed = self._enemyEntityFactory:GetCurrentMoveSpeed(entity)
	end

	local resolvedMoveSpeed = if type(currentMoveSpeed) == "number" and currentMoveSpeed > 0 then currentMoveSpeed else 16
	local walkSpeedWriteEpsilon = self:_GetWalkSpeedWriteEpsilon(sepConfig)
	if humanoid ~= nil and math.abs(humanoid.WalkSpeed - resolvedMoveSpeed) > walkSpeedWriteEpsilon then
		humanoid.WalkSpeed = resolvedMoveSpeed
	end
	refs.LastWalkSpeed = resolvedMoveSpeed

	return resolvedMoveSpeed
end

function MovementService:_StopHumanoid(entity: number)
	local humanoid = self:_GetHumanoid(entity)
	if humanoid ~= nil then
		humanoid:Move(Vector3.zero)
	end
end

function MovementService:_IsFastFlowDebugEnabled(): boolean
	return CombatMovementConfig.FASTFLOW_VISUALIZATION.Enabled == true
		or CombatMovementConfig.FASTFLOW_ARROW_VISUALIZATION.Enabled == true
end

function MovementService:_IsFastFlowProfilingEnabled(): boolean
	local profileConfig = CombatMovementConfig.FASTFLOW_PROFILING
	return profileConfig ~= nil and profileConfig.Enabled == true
end

function MovementService:_ResetFastFlowProfileCounters()
	if not self:_IsFastFlowProfilingEnabled() then
		self._fastFlowProfileCounters = nil
		return
	end

	self._fastFlowProfileCounters = {
		SharedFieldCreations = 0,
		SharedFieldRefreshes = 0,
		MergeAttempts = 0,
		TrackedFlowEntities = 0,
		ActiveSeparationEntities = 0,
		DenseCellsEncountered = 0,
		DenseCellFallbackActivations = 0,
		DirtyEntitiesProcessed = 0,
		DirtyCellsProcessed = 0,
		LocalPairSolves = 0,
		BucketMembershipUpdates = 0,
		CachedRootPartHits = 0,
		CachedRootPartMisses = 0,
		CachedHumanoidHits = 0,
		CachedHumanoidMisses = 0,
		SpatialRefreshCalls = 0,
		CoveredCellRecomputes = 0,
		NearGoalBandRecomputes = 0,
		DirtyMarksTriggered = 0,
		DirtyMarksSkipped = 0,
	}
end

function MovementService:_IncrementFastFlowProfileCounter(counterKey: string, amount: number?)
	local counters = self._fastFlowProfileCounters
	if counters == nil then
		return
	end

	counters[counterKey] += if amount ~= nil then amount else 1
end

function MovementService:_SetFastFlowProfileCounter(counterKey: string, value: number)
	local counters = self._fastFlowProfileCounters
	if counters == nil then
		return
	end

	counters[counterKey] = value
end

function MovementService:_EmitFastFlowProfileCounters()
	local counters = self._fastFlowProfileCounters
	if counters == nil then
		return
	end

	local profileConfig = CombatMovementConfig.FASTFLOW_PROFILING
	local logInterval = if profileConfig ~= nil and type(profileConfig.LogIntervalSeconds) == "number"
		then math.max(0.25, profileConfig.LogIntervalSeconds)
		else 1
	local now = os.clock()
	if now - self._lastFastFlowProfileLogAt < logInterval then
		return
	end

	self._lastFastFlowProfileLogAt = now
	warn(string.format(
		"FastFlow profile | sharedCreates=%d sharedRefreshes=%d merges=%d tracked=%d activeSeparation=%d dirtyEntities=%d dirtyCells=%d localPairs=%d bucketUpdates=%d rootHits=%d rootMisses=%d humanoidHits=%d humanoidMisses=%d spatialRefreshes=%d cellRecomputes=%d nearGoalRecomputes=%d dirtyTriggered=%d dirtySkipped=%d denseCells=%d denseFallbacks=%d",
		counters.SharedFieldCreations,
		counters.SharedFieldRefreshes,
		counters.MergeAttempts,
		counters.TrackedFlowEntities,
		counters.ActiveSeparationEntities,
		counters.DirtyEntitiesProcessed,
		counters.DirtyCellsProcessed,
		counters.LocalPairSolves,
		counters.BucketMembershipUpdates,
		counters.CachedRootPartHits,
		counters.CachedRootPartMisses,
		counters.CachedHumanoidHits,
		counters.CachedHumanoidMisses,
		counters.SpatialRefreshCalls,
		counters.CoveredCellRecomputes,
		counters.NearGoalBandRecomputes,
		counters.DirtyMarksTriggered,
		counters.DirtyMarksSkipped,
		counters.DenseCellsEncountered,
		counters.DenseCellFallbackActivations
	))
end

function MovementService:_CountTableEntries(source: { [any]: any }): number
	local count = 0
	for _ in source do
		count += 1
	end
	return count
end

function MovementService:_GetFastFlowSharedFieldConfig(): { [string]: any }
	return CombatMovementConfig.FASTFLOW_SHARED_FIELDS
end

function MovementService:_ResolveFastFlowRuntime(): (any?, FastFlowHelper.TFlowGridMapping?)
	local mapping = self._fastFlowMapping
	local pathfinder = self._fastFlowPathfinder
	if pathfinder == nil or mapping == nil then
		return nil, nil
	end
	if mapping.CellWidthStuds <= 0 then
		return nil, nil
	end
	return pathfinder, mapping
end

function MovementService:_ResolveFlowGoal(
	goalPosition: Vector3
): (any?, FastFlowHelper.TFlowGridMapping?, Vector2?, Vector3?, string?)
	local pathfinder, mapping = self:_ResolveFastFlowRuntime()
	if pathfinder == nil or mapping == nil then
		return nil, nil, nil, nil, "FastFlowNotConfigured"
	end

	local goalCell = pathfinder:FindOpenCell(FastFlowHelper.WorldXZToGridCell(goalPosition, mapping))
	if goalCell == nil then
		return pathfinder, mapping, nil, nil, "FastFlowGenerateFailed"
	end

	local goalWorldSample = FastFlowHelper.GridCellToWorldXZ(goalCell, mapping, goalPosition.Y)
	return pathfinder, mapping, goalCell, goalWorldSample, nil
end

function MovementService:_GetSharedRepresentativeStarts(goalKey: string): { Vector3 }?
	if not self:_UsePrunedSharedGeneration() then
		return nil
	end

	local starts: { Vector3 } = {}
	local maxStarts = self:_GetSharedRepresentativeStartCap()
	local activeEntities = self._activeFlowEntitiesByGoalKey[goalKey]
	if activeEntities == nil then
		return nil
	end

	for entityId in activeEntities do
		if #starts >= maxStarts then
			break
		end

		local movementState = self._movementByEntity[entityId]
		if movementState ~= nil and movementState.Mode == "Flow" and self._flowSettledByEntity[entityId] ~= true then
			local entityPosition = self:_GetEntityPosition(entityId)
			if entityPosition ~= nil then
				table.insert(starts, entityPosition)
			end
		end
	end

	if #starts == 0 then
		return nil
	end

	return starts
end

function MovementService:_CreateSharedFlowfield(
	goalKey: string,
	goalCell: Vector2,
	goalWorldSample: Vector3
): (TSharedFlowfieldEntry?, string?)
	local pathfinder, mapping = self:_ResolveFastFlowRuntime()
	if pathfinder == nil or mapping == nil then
		return nil, "FastFlowNotConfigured"
	end

	local representativeStarts = self:_GetSharedRepresentativeStarts(goalKey)
	local flowfield = FastFlowHelper.GenerateFlowfieldWorld(pathfinder, goalWorldSample, mapping, representativeStarts)
	if flowfield == nil and representativeStarts ~= nil then
		flowfield = FastFlowHelper.GenerateFlowfieldWorld(pathfinder, goalWorldSample, mapping, nil)
	end
	if flowfield == nil then
		return nil, "FastFlowGenerateFailed"
	end

	local entry: TSharedFlowfieldEntry = {
		Flowfield = flowfield,
		GoalCell = goalCell,
		GoalWorldSample = goalWorldSample,
		LastRefreshClock = os.clock(),
		RefreshInProgress = false,
		RefCount = 0,
	}
	self:_IncrementFastFlowProfileCounter("SharedFieldCreations")
	self:_EmitFlowfieldDebug(flowfield, goalWorldSample)
	return entry, nil
end

function MovementService:_ResolveSharedFlowfield(
	goalPosition: Vector3,
	forceRefresh: boolean?
): (string?, Vector3?, string?)
	local _pathfinder, _mapping, goalCell, goalWorldSample, reason = self:_ResolveFlowGoal(goalPosition)
	if goalCell == nil or goalWorldSample == nil then
		return nil, nil, if reason ~= nil then reason else "FastFlowGenerateFailed"
	end

	local goalKey = _FlowGoalKey(goalCell)
	local existingEntry = self._sharedFlowfieldsByGoalKey[goalKey]
	if existingEntry ~= nil and forceRefresh ~= true then
		return goalKey, existingEntry.GoalWorldSample, nil
	end

	if existingEntry ~= nil and forceRefresh == true then
		if existingEntry.RefreshInProgress then
			return goalKey, existingEntry.GoalWorldSample, nil
		end

		if self:_AllowSingleSharedRefreshPerCooldown() then
			local refreshCooldown = self:_GetSharedFlowfieldRefreshCooldownSeconds(CombatMovementConfig.FLOW_SOFT_SEPARATION)
			if os.clock() - existingEntry.LastRefreshClock < refreshCooldown then
				return goalKey, existingEntry.GoalWorldSample, nil
			end
		end
	end

	if existingEntry ~= nil then
		existingEntry.RefreshInProgress = true
	end

	local newEntry, createReason = self:_CreateSharedFlowfield(goalKey, goalCell, goalWorldSample)
	if newEntry == nil then
		if existingEntry ~= nil then
			existingEntry.RefreshInProgress = false
		end
		return nil, nil, if createReason ~= nil then createReason else "FastFlowGenerateFailed"
	end

	if existingEntry ~= nil then
		newEntry.RefCount = existingEntry.RefCount
		self:_IncrementFastFlowProfileCounter("SharedFieldRefreshes")
	end
	self._sharedFlowfieldsByGoalKey[goalKey] = newEntry
	return goalKey, newEntry.GoalWorldSample, nil
end

function MovementService:_GetSharedFlowfieldEntry(goalKey: string?): TSharedFlowfieldEntry?
	if goalKey == nil then
		return nil
	end
	return self._sharedFlowfieldsByGoalKey[goalKey]
end

function MovementService:_DetachSharedFlowfield(goalKey: string?)
	if goalKey == nil then
		return
	end

	local entry = self._sharedFlowfieldsByGoalKey[goalKey]
	if entry == nil then
		return
	end

	entry.RefCount = math.max(0, entry.RefCount - 1)
	if entry.RefCount == 0 then
		self._sharedFlowfieldsByGoalKey[goalKey] = nil
	end
end

function MovementService:_RemoveEntityFromActiveFlowGoal(entity: number, goalKey: string?)
	if goalKey == nil then
		return
	end

	local activeEntities = self._activeFlowEntitiesByGoalKey[goalKey]
	if activeEntities == nil then
		return
	end

	activeEntities[entity] = nil
	if next(activeEntities) == nil then
		self._activeFlowEntitiesByGoalKey[goalKey] = nil
	end
end

function MovementService:_AddEntityToActiveFlowGoal(entity: number, goalKey: string?)
	if goalKey == nil then
		return
	end

	local activeEntities = self._activeFlowEntitiesByGoalKey[goalKey]
	if activeEntities == nil then
		activeEntities = {}
		self._activeFlowEntitiesByGoalKey[goalKey] = activeEntities
	end

	activeEntities[entity] = true
end

function MovementService:_RefreshActiveFlowGoalMembership(entity: number, previousGoalKey: string?)
	local currentGoalKey = self._flowGoalKeyByEntity[entity]
	if previousGoalKey ~= currentGoalKey then
		self:_RemoveEntityFromActiveFlowGoal(entity, previousGoalKey)
	end

	local movementState = self._movementByEntity[entity]
	local isActiveFlowMember = movementState ~= nil
		and movementState.Mode == "Flow"
		and currentGoalKey ~= nil
		and self._flowSettledByEntity[entity] ~= true

	if isActiveFlowMember then
		self:_AddEntityToActiveFlowGoal(entity, currentGoalKey)
	else
		self:_RemoveEntityFromActiveFlowGoal(entity, currentGoalKey)
	end
end

function MovementService:_AttachEntityToSharedFlowfield(entity: number, goalKey: string)
	local currentGoalKey = self._flowGoalKeyByEntity[entity]
	if currentGoalKey == goalKey then
		return
	end

	self:_DetachSharedFlowfield(currentGoalKey)

	local entry = self._sharedFlowfieldsByGoalKey[goalKey]
	if entry ~= nil then
		entry.RefCount += 1
	end
	self._flowGoalKeyByEntity[entity] = goalKey
	self:_RefreshActiveFlowGoalMembership(entity, currentGoalKey)
end

function MovementService:_ClearFlowSettlementState(entity: number)
	local previousGoalKey = self._flowGoalKeyByEntity[entity]
	self._flowSettledByEntity[entity] = nil
	self._flowSettleAnchorGoalKeyByEntity[entity] = nil
	self:_RefreshActiveFlowGoalMembership(entity, previousGoalKey)
end

function MovementService:_MarkFlowSettled(entity: number, goalKey: string)
	local previousGoalKey = self._flowGoalKeyByEntity[entity]
	self._flowSettledByEntity[entity] = true
	self._flowSettleAnchorGoalKeyByEntity[entity] = goalKey
	self._flowVelByEntity[entity] = Vector2.zero
	self:_RefreshActiveFlowGoalMembership(entity, previousGoalKey)
	self:_RefreshFlowSeparationEntitySpatialState(entity)
end

function MovementService:_AttachEntityToFlowGoal(
	entity: number,
	goalPosition: Vector3,
	forceRefresh: boolean?
): (string?, Vector3?, string?)
	local goalKey, goalWorldSample, reason = self:_ResolveSharedFlowfield(goalPosition, forceRefresh)
	if goalKey == nil or goalWorldSample == nil then
		return nil, nil, if reason ~= nil then reason else "FastFlowGenerateFailed"
	end

	self:_AttachEntityToSharedFlowfield(entity, goalKey)
	self:_ClearFlowSettlementState(entity)
	self:_RefreshFlowSeparationEntitySpatialState(entity)
	return goalKey, goalWorldSample, nil
end

function MovementService:_ClearMovementRuntimeState(entity: number, preserveSettleAnchorGoalKey: string?)
	local currentGoalKey = self._flowGoalKeyByEntity[entity]
	self:_RemoveEntityFromActiveFlowGoal(entity, currentGoalKey)
	self._movementByEntity[entity] = nil
	self._flowVelByEntity[entity] = nil
	self._flowSteeringRepairAtClockByEntity[entity] = nil
	self._flowSettledByEntity[entity] = nil
	self:_DetachSharedFlowfield(currentGoalKey)
	self._flowGoalKeyByEntity[entity] = nil

	if preserveSettleAnchorGoalKey ~= nil then
		self._flowSettleAnchorGoalKeyByEntity[entity] = preserveSettleAnchorGoalKey
	else
		self._flowSettleAnchorGoalKeyByEntity[entity] = nil
	end

	self:_RefreshFlowSeparationEntitySpatialState(entity)
	self:_InvalidateFlowActorRefs(entity)

	self._enemyEntityFactory:SetPathMoving(entity, false)
	if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
		self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
	end
end

function MovementService:_BuildEndpointDiagnostic(
	worldPosition: Vector3,
	pathfinder: any,
	mapping: FastFlowHelper.TFlowGridMapping
): { World: Vector3, Cell: Vector2, InBounds: boolean, IsWall: boolean, IsBorder: boolean, RegionNil: boolean, Size: number }
	local cell = FastFlowHelper.WorldXZToGridCell(worldPosition, mapping)
	local walls = pathfinder._Walls
	local regions = pathfinder._Regions
	local size = if walls ~= nil then walls._Size else 0
	local inBounds = if walls ~= nil then walls:IsCellInBounds(cell) else false
	local isWall = if walls ~= nil then walls:GetCell(cell) == true else false
	local isBorder = math.abs(cell.X) >= size or math.abs(cell.Y) >= size
	local regionNil = if regions ~= nil then regions:GetCell(cell) == nil else false

	return {
		World = worldPosition,
		Cell = cell,
		InBounds = inBounds,
		IsWall = isWall,
		IsBorder = isBorder,
		RegionNil = regionNil,
		Size = size,
	}
end

function MovementService:_EmitFastFlowEndpointDiagnostic(
	entity: number,
	entityPosition: Vector3,
	goalPosition: Vector3,
	pathfinder: any,
	mapping: FastFlowHelper.TFlowGridMapping
)
	local start = self:_BuildEndpointDiagnostic(entityPosition, pathfinder, mapping)
	local goal = self:_BuildEndpointDiagnostic(goalPosition, pathfinder, mapping)
	local shouldLog = start.RegionNil or goal.RegionNil or not start.InBounds or not goal.InBounds or start.IsWall or goal.IsWall
	if not shouldLog then
		return
	end

	local diagnosticKey = string.format(
		"%d|%d,%d|%d,%d|%s|%s|%s|%s|%s|%s",
		entity,
		start.Cell.X,
		start.Cell.Y,
		goal.Cell.X,
		goal.Cell.Y,
		tostring(start.InBounds),
		tostring(goal.InBounds),
		tostring(start.IsWall),
		tostring(goal.IsWall),
		tostring(start.RegionNil),
		tostring(goal.RegionNil)
	)
	if self._lastFastFlowEndpointDiagnosticKey == diagnosticKey then
		return
	end
	self._lastFastFlowEndpointDiagnosticKey = diagnosticKey

	warn(
		string.format(
			"FastFlow endpoint diagnostic | entity=%s | startWorld=(%.2f, %.2f, %.2f) startCell=(%d,%d) inBounds=%s wall=%s border=%s regionNil=%s | goalWorld=(%.2f, %.2f, %.2f) goalCell=(%d,%d) inBounds=%s wall=%s border=%s regionNil=%s | gridHalfSize=%d",
			tostring(entity),
			start.World.X,
			start.World.Y,
			start.World.Z,
			start.Cell.X,
			start.Cell.Y,
			tostring(start.InBounds),
			tostring(start.IsWall),
			tostring(start.IsBorder),
			tostring(start.RegionNil),
			goal.World.X,
			goal.World.Y,
			goal.World.Z,
			goal.Cell.X,
			goal.Cell.Y,
			tostring(goal.InBounds),
			tostring(goal.IsWall),
			tostring(goal.IsBorder),
			tostring(goal.RegionNil),
			start.Size
		)
	)
end

function MovementService:_EmitFlowfieldDebug(flowfield: any, goalPosition: Vector3)
	local renderer = self._flowfieldDebugRenderer
	local _pathfinder, mapping = self:_ResolveFastFlowRuntime()
	if renderer == nil or mapping == nil or not self:_IsFastFlowDebugEnabled() then
		return
	end

	renderer(flowfield, mapping, goalPosition)
end

function MovementService:_StartFlow(entity: number, goalPosition: Vector3): (boolean, string?)
	local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, false)
	if goalKey == nil or goalWorldSample == nil then
		local pathfinder, mapping = self:_ResolveFastFlowRuntime()
		local entityPosition = self:_GetEntityPosition(entity)
		if pathfinder ~= nil and mapping ~= nil and entityPosition ~= nil then
			self:_EmitFastFlowEndpointDiagnostic(entity, entityPosition, goalPosition, pathfinder, mapping)
		end
		return false, reason
	end

	self._movementByEntity[entity] = {
		Mode = "Flow",
		GoalSnapshot = goalPosition,
		GoalKey = goalKey,
		GoalWorldSample = goalWorldSample,
	}
	self:_GetEntityRootPart(entity)
	self:_GetHumanoid(entity)
	self:_RefreshFlowSeparationEntitySpatialState(entity)
	self._enemyEntityFactory:SetPathMoving(entity, true)
	return true, nil
end

function MovementService:_GetFlowArrivalThreshold(): number
	local configuredThreshold = BoidsConfig.ArrivalThreshold
	if type(configuredThreshold) ~= "number" or configuredThreshold <= 0 then
		return 2.75
	end
	return configuredThreshold
end

function MovementService:_GetFlowClumpIdleRadiusStuds(sepConfig: any): number
	local configuredRadius = if sepConfig ~= nil then sepConfig.ClumpIdleRadiusStuds else nil
	if type(configuredRadius) == "number" and configuredRadius > 0 then
		return configuredRadius
	end
	return self:_GetFlowArrivalThreshold() * 2.5
end

function MovementService:_GetFlowClumpTouchPaddingStuds(sepConfig: any): number
	local configuredPadding = if sepConfig ~= nil then sepConfig.ClumpTouchDistancePaddingStuds else nil
	if type(configuredPadding) == "number" and configuredPadding >= 0 then
		return configuredPadding
	end
	return 0.5
end

function MovementService:_GetSharedFlowfieldRefreshCooldownSeconds(sepConfig: any): number
	local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
	local configuredCooldown = if sharedFieldConfig ~= nil then sharedFieldConfig.RefreshCooldownSeconds else nil
	if type(configuredCooldown) == "number" and configuredCooldown > 0 then
		return configuredCooldown
	end

	configuredCooldown = if sepConfig ~= nil then sepConfig.SharedFlowfieldRefreshCooldownSeconds else nil
	if type(configuredCooldown) == "number" and configuredCooldown > 0 then
		return configuredCooldown
	end
	return 0.35
end

function MovementService:_UsePrunedSharedGeneration(): boolean
	local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
	return sharedFieldConfig ~= nil and sharedFieldConfig.UsePrunedGeneration == true
end

function MovementService:_AllowSingleSharedRefreshPerCooldown(): boolean
	local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
	return sharedFieldConfig == nil or sharedFieldConfig.AllowSingleRefreshPerCooldown ~= false
end

function MovementService:_GetSharedRepresentativeStartCap(): number
	local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
	local configuredCap = if sharedFieldConfig ~= nil then sharedFieldConfig.RepresentativeStartCap else nil
	if type(configuredCap) == "number" and configuredCap > 0 then
		return math.max(1, math.floor(configuredCap))
	end
	return 8
end

function MovementService:_GetIsolationSkipRadiusStuds(sepConfig: any): number
	local configuredRadius = if sepConfig ~= nil then sepConfig.IsolationSkipRadiusStuds else nil
	if type(configuredRadius) == "number" and configuredRadius > 0 then
		return configuredRadius
	end
	return 6
end

function MovementService:_UseIsolationSkip(sepConfig: any): boolean
	return sepConfig ~= nil and sepConfig.IsolationSkipEnabled == true
end

function MovementService:_UseDenseCellFallback(sepConfig: any): boolean
	return sepConfig ~= nil and sepConfig.DenseCellFallbackEnabled == true
end

function MovementService:_GetDenseCellOccupancyThreshold(sepConfig: any): number
	local configuredThreshold = if sepConfig ~= nil then sepConfig.DenseCellOccupancyThreshold else nil
	if type(configuredThreshold) == "number" and configuredThreshold >= 2 then
		return math.max(2, math.floor(configuredThreshold))
	end
	return 10
end

function MovementService:_GetNearGoalSeparationScale(sepConfig: any): number
	local configuredScale = if sepConfig ~= nil then sepConfig.NearGoalSeparationScale else nil
	if type(configuredScale) == "number" and configuredScale >= 0 then
		return math.clamp(configuredScale, 0, 1)
	end
	return 0.35
end

function MovementService:_GetNearGoalSeparationRadiusStuds(sepConfig: any): number
	local configuredRadius = if sepConfig ~= nil then sepConfig.NearGoalSeparationRadiusStuds else nil
	if type(configuredRadius) == "number" and configuredRadius > 0 then
		return configuredRadius
	end
	return 8
end

function MovementService:_GetNeighborDirtyMoveThresholdStuds(sepConfig: any, cellWidthStuds: number): number
	local configuredThreshold = if sepConfig ~= nil then sepConfig.NeighborDirtyMoveThresholdStuds else nil
	if type(configuredThreshold) == "number" and configuredThreshold > 0 then
		return configuredThreshold
	end
	return math.max(0.5, cellWidthStuds * 0.5)
end

function MovementService:_GetAgentRadiusStuds(entity: number): number
	local params = self:_GetAgentParams(entity)
	local agentRadius = params.AgentRadius
	if type(agentRadius) == "number" and agentRadius > 0 then
		return agentRadius
	end
	return 2
end

function MovementService:_CreateFlowSeparationRuntime(sessionUserId: number?, currentTime: number?): TFlowSeparationRuntime
	return {
		SessionUserId = sessionUserId,
		CurrentTime = currentTime,
		CellWidthStuds = 0,
		EntityStateById = {},
		BucketsByCell = {},
		DirtyEntities = {},
		DirtyCells = {},
		TrackedFlowEntities = {},
		ActiveFlowEntities = {},
		ActiveSolveEntities = {},
	}
end

function MovementService:_GetOrCreateFlowSeparationRuntime(): TFlowSeparationRuntime
	local runtime = self._flowSeparationRuntime
	if runtime == nil then
		runtime = self:_CreateFlowSeparationRuntime(nil, nil)
		self._flowSeparationRuntime = runtime
	end
	return runtime
end

function MovementService:_AreCoveredCellsEqual(
	leftCells: { TFlowSeparationCoveredCell },
	rightCells: { TFlowSeparationCoveredCell }
): boolean
	if #leftCells ~= #rightCells then
		return false
	end

	for index = 1, #leftCells do
		if leftCells[index].Key ~= rightCells[index].Key then
			return false
		end
	end

	return true
end

function MovementService:_BuildFlowSeparationCoveredCells(
	flatPosition: Vector2,
	radius: number,
	cellWidthStuds: number
): { TFlowSeparationCoveredCell }
	local coveredCells: { TFlowSeparationCoveredCell } = {}
	_ForEachCoveredSeparationCell(flatPosition, radius, cellWidthStuds, function(gx: number, gz: number)
		table.insert(coveredCells, {
			Key = _PackedSeparationCellKey(gx, gz),
			Gx = gx,
			Gz = gz,
		})
	end)
	return coveredCells
end

function MovementService:_InsertEntityIntoFlowSeparationBuckets(
	entity: number,
	coveredCells: { TFlowSeparationCoveredCell }
)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	for _, coveredCell in ipairs(coveredCells) do
		local bucket = runtime.BucketsByCell[coveredCell.Key]
		if bucket == nil then
			bucket = {}
			runtime.BucketsByCell[coveredCell.Key] = bucket
		end
		bucket[entity] = true
	end
	self:_IncrementFastFlowProfileCounter("BucketMembershipUpdates")
end

function MovementService:_RemoveEntityFromFlowSeparationBuckets(
	entity: number,
	coveredCells: { TFlowSeparationCoveredCell }
)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	for _, coveredCell in ipairs(coveredCells) do
		local bucket = runtime.BucketsByCell[coveredCell.Key]
		if bucket ~= nil then
			bucket[entity] = nil
			if next(bucket) == nil then
				runtime.BucketsByCell[coveredCell.Key] = nil
			end
		end
	end
	self:_IncrementFastFlowProfileCounter("BucketMembershipUpdates")
end

function MovementService:_MarkFlowSeparationCellsDirty(
	coveredCells: { TFlowSeparationCoveredCell }
)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	for _, coveredCell in ipairs(coveredCells) do
		for gx = coveredCell.Gx - 1, coveredCell.Gx + 1 do
			for gz = coveredCell.Gz - 1, coveredCell.Gz + 1 do
				local key = _PackedSeparationCellKey(gx, gz)
				runtime.DirtyCells[key] = true
				local bucket = runtime.BucketsByCell[key]
				if bucket ~= nil then
					for entityId in bucket do
						runtime.DirtyEntities[entityId] = true
					end
				end
			end
		end
	end
end

function MovementService:_MarkFlowSeparationEntityDirty(entity: number)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	runtime.DirtyEntities[entity] = true
end

function MovementService:_GetFlowSeparationDesiredCellWidth(): number
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local maxRadius = 0
	for entityId in runtime.TrackedFlowEntities do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil and entityState.Position ~= nil and entityState.Radius > maxRadius then
			maxRadius = entityState.Radius
		end
	end

	if maxRadius <= 0 then
		maxRadius = 2
	end

	return maxRadius * 2
end

function MovementService:_RefreshFlowSeparationCellWidth(): boolean
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local desiredCellWidthStuds = self:_GetFlowSeparationDesiredCellWidth()
	if math.abs(runtime.CellWidthStuds - desiredCellWidthStuds) <= 1e-4 then
		return false
	end

	runtime.CellWidthStuds = desiredCellWidthStuds
	table.clear(runtime.BucketsByCell)
	table.clear(runtime.DirtyCells)
	table.clear(runtime.DirtyEntities)
	table.clear(runtime.ActiveSolveEntities)

	for entityId in runtime.TrackedFlowEntities do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil then
			entityState.CoveredCells = {}
			entityState.Separation = Vector2.zero
			if entityState.FlatPosition ~= nil then
				entityState.CoveredCells = self:_BuildFlowSeparationCoveredCells(
					entityState.FlatPosition,
					entityState.Radius,
					runtime.CellWidthStuds
				)
				self:_InsertEntityIntoFlowSeparationBuckets(entityId, entityState.CoveredCells)
				self:_MarkFlowSeparationCellsDirty(entityState.CoveredCells)
			end
			runtime.DirtyEntities[entityId] = true
		end
	end

	return true
end

function MovementService:_ComputeFlowSeparationNearGoalScale(
	entityPosition: Vector3?,
	goalKey: string?,
	sepConfig: any
): number
	if entityPosition == nil or goalKey == nil then
		return 1
	end

	local nearGoalScale = self:_GetNearGoalSeparationScale(sepConfig)
	local nearGoalRadiusStuds = self:_GetNearGoalSeparationRadiusStuds(sepConfig)
	if nearGoalScale >= 1 or nearGoalRadiusStuds <= 0 then
		return 1
	end

	local sharedEntry = self:_GetSharedFlowfieldEntry(goalKey)
	if sharedEntry == nil then
		return 1
	end

	if _XZDistance(entityPosition, sharedEntry.GoalWorldSample) <= nearGoalRadiusStuds then
		return nearGoalScale
	end

	return 1
end

function MovementService:_IsFlowEntityInsideNearGoalBand(
	entityPosition: Vector3?,
	goalKey: string?,
	sepConfig: any
): boolean
	return self:_ComputeFlowSeparationNearGoalScale(entityPosition, goalKey, sepConfig) < 1
end

function MovementService:_HasFlowSeparationMaterialMove(
	previousFlatPosition: Vector2?,
	nextFlatPosition: Vector2?,
	cellWidthStuds: number
): boolean
	if previousFlatPosition == nil or nextFlatPosition == nil then
		return previousFlatPosition ~= nextFlatPosition
	end

	local moveThreshold = math.max(0.25, cellWidthStuds * FLOW_SEPARATION_MATERIAL_MOVE_RATIO)
	return (previousFlatPosition - nextFlatPosition).Magnitude >= moveThreshold
end

function MovementService:_RemoveFlowSeparationEntity(entity: number)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local entityState = runtime.EntityStateById[entity]
	if entityState == nil then
		runtime.TrackedFlowEntities[entity] = nil
		runtime.ActiveFlowEntities[entity] = nil
		runtime.ActiveSolveEntities[entity] = nil
		runtime.DirtyEntities[entity] = nil
		return
	end

	local oldCoveredCells = entityState.CoveredCells
	if #oldCoveredCells > 0 then
		self:_RemoveEntityFromFlowSeparationBuckets(entity, oldCoveredCells)
		self:_MarkFlowSeparationCellsDirty(oldCoveredCells)
	end

	runtime.EntityStateById[entity] = nil
	runtime.TrackedFlowEntities[entity] = nil
	runtime.ActiveFlowEntities[entity] = nil
	runtime.ActiveSolveEntities[entity] = nil
	runtime.DirtyEntities[entity] = nil
	self:_RefreshFlowSeparationCellWidth()
end

function MovementService:_RefreshFlowSeparationEntitySpatialState(
	entity: number,
	entityPosition: Vector3?
): TFlowSeparationEntityState?
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	self:_IncrementFastFlowProfileCounter("SpatialRefreshCalls")
	local movementState = self._movementByEntity[entity]
	local tracked = (movementState ~= nil and movementState.Mode == "Flow")
		or self._flowSettleAnchorGoalKeyByEntity[entity] ~= nil
	if not tracked then
		self:_RemoveFlowSeparationEntity(entity)
		return nil
	end

	local resolvedPosition = if entityPosition ~= nil then entityPosition else self:_GetEntityPosition(entity)
	local flatPosition = if resolvedPosition ~= nil then _FlatXZ(resolvedPosition) else nil
	local goalKey = self._flowGoalKeyByEntity[entity] or self._flowSettleAnchorGoalKeyByEntity[entity]
	local settled = self._flowSettledByEntity[entity] == true or self._flowSettleAnchorGoalKeyByEntity[entity] ~= nil
	local active = movementState ~= nil and movementState.Mode == "Flow" and resolvedPosition ~= nil and not settled
	local radius = self:_GetAgentRadiusStuds(entity)
	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION

	local entityState = runtime.EntityStateById[entity]
	local previousCoveredCells = if entityState ~= nil then entityState.CoveredCells else {}
	local previousFlatPosition = if entityState ~= nil then entityState.FlatPosition else nil
	local previousGoalKey = if entityState ~= nil then entityState.GoalKey else nil
	local previousSettled = if entityState ~= nil then entityState.Settled else false
	local previousActive = if entityState ~= nil then entityState.Active else false
	local previousRadius = if entityState ~= nil then entityState.Radius else -1
	local previousLastSpatialRefreshFlatPosition = if entityState ~= nil then entityState.LastSpatialRefreshFlatPosition else nil
	local previousIsInsideNearGoalBand = if entityState ~= nil then entityState.IsInsideNearGoalBand else false
	local previousLastGoalKey = if entityState ~= nil then entityState.LastGoalKey else nil
	local previousLastDirtyMarkFlatPosition = if entityState ~= nil then entityState.LastDirtyMarkFlatPosition else nil

	if entityState == nil then
		entityState = {
			Position = nil,
			FlatPosition = nil,
			Radius = radius,
			GoalKey = nil,
			Settled = false,
			Active = false,
			CoveredCells = {},
			Separation = Vector2.zero,
			NearGoalScale = 1,
			LastSpatialRefreshFlatPosition = nil,
			IsInsideNearGoalBand = false,
			LastGoalKey = nil,
			LastDirtyMarkFlatPosition = nil,
		}
		runtime.EntityStateById[entity] = entityState
	end

	entityState.Position = resolvedPosition
	entityState.FlatPosition = flatPosition
	entityState.Radius = radius
	entityState.GoalKey = goalKey
	entityState.Settled = settled
	entityState.Active = active

	runtime.TrackedFlowEntities[entity] = true
	if active then
		runtime.ActiveFlowEntities[entity] = true
	else
		runtime.ActiveFlowEntities[entity] = nil
	end

	local didRebuildCellWidth = false
	if runtime.CellWidthStuds <= 0 or previousRadius ~= radius then
		didRebuildCellWidth = self:_RefreshFlowSeparationCellWidth()
	end

	local stateFlagsChanged = previousGoalKey ~= goalKey or previousSettled ~= settled or previousActive ~= active
	local materiallyMoved = not didRebuildCellWidth
		and self:_HasFlowSeparationMaterialMove(previousLastSpatialRefreshFlatPosition, flatPosition, runtime.CellWidthStuds)
	local shouldRecomputeNearGoalBand = goalKey ~= previousLastGoalKey
		or self:_HasFlowSeparationMaterialMove(previousFlatPosition, flatPosition, runtime.CellWidthStuds)
	if shouldRecomputeNearGoalBand then
		entityState.IsInsideNearGoalBand = self:_IsFlowEntityInsideNearGoalBand(resolvedPosition, goalKey, sepConfig)
		entityState.NearGoalScale = if entityState.IsInsideNearGoalBand
			then self:_GetNearGoalSeparationScale(sepConfig)
			else 1
		entityState.LastGoalKey = goalKey
		self:_IncrementFastFlowProfileCounter("NearGoalBandRecomputes")
	else
		entityState.IsInsideNearGoalBand = previousIsInsideNearGoalBand
		entityState.NearGoalScale = if previousIsInsideNearGoalBand then self:_GetNearGoalSeparationScale(sepConfig) else 1
		entityState.LastGoalKey = previousLastGoalKey
	end

	local nextCoveredCells = entityState.CoveredCells
	local shouldRecomputeCoveredCells = didRebuildCellWidth or stateFlagsChanged or materiallyMoved
	if shouldRecomputeCoveredCells and not didRebuildCellWidth then
		nextCoveredCells = if flatPosition ~= nil
			then self:_BuildFlowSeparationCoveredCells(flatPosition, radius, runtime.CellWidthStuds)
			else {}
		self:_IncrementFastFlowProfileCounter("CoveredCellRecomputes")
	end

	local coveredCellsChanged = not didRebuildCellWidth
		and not self:_AreCoveredCellsEqual(previousCoveredCells, nextCoveredCells)
	local dirtyMoveThreshold = self:_GetNeighborDirtyMoveThresholdStuds(sepConfig, runtime.CellWidthStuds)
	local dirtyMoved = if previousLastDirtyMarkFlatPosition ~= nil and flatPosition ~= nil
		then (previousLastDirtyMarkFlatPosition - flatPosition).Magnitude >= dirtyMoveThreshold
		else flatPosition ~= previousLastDirtyMarkFlatPosition

	if not didRebuildCellWidth and coveredCellsChanged then
		if #previousCoveredCells > 0 then
			self:_RemoveEntityFromFlowSeparationBuckets(entity, previousCoveredCells)
		end
		entityState.CoveredCells = nextCoveredCells
		if #nextCoveredCells > 0 then
			self:_InsertEntityIntoFlowSeparationBuckets(entity, nextCoveredCells)
		end
		self:_MarkFlowSeparationCellsDirty(previousCoveredCells)
		self:_MarkFlowSeparationCellsDirty(nextCoveredCells)
		entityState.LastDirtyMarkFlatPosition = flatPosition
		self:_IncrementFastFlowProfileCounter("DirtyMarksTriggered")
	elseif shouldRecomputeCoveredCells and not didRebuildCellWidth then
		entityState.CoveredCells = nextCoveredCells
		if stateFlagsChanged or dirtyMoved then
			self:_MarkFlowSeparationCellsDirty(nextCoveredCells)
			entityState.LastDirtyMarkFlatPosition = flatPosition
			self:_IncrementFastFlowProfileCounter("DirtyMarksTriggered")
		elseif materiallyMoved then
			self:_IncrementFastFlowProfileCounter("DirtyMarksSkipped")
		end
	end

	if shouldRecomputeCoveredCells then
		entityState.LastSpatialRefreshFlatPosition = flatPosition
	end

	if didRebuildCellWidth or coveredCellsChanged or stateFlagsChanged or dirtyMoved then
		entityState.Separation = Vector2.zero
		runtime.ActiveSolveEntities[entity] = nil
		self:_MarkFlowSeparationEntityDirty(entity)
	end

	return entityState
end

function MovementService:_CollectFlowSeparationAffectedEntities(): ({ [number]: boolean }, { number })
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local affectedEntitySet: { [number]: boolean } = {}
	local affectedEntities: { number } = {}

	for entityId in runtime.DirtyEntities do
		affectedEntitySet[entityId] = true
	end

	for dirtyCellKey in runtime.DirtyCells do
		local bucket = runtime.BucketsByCell[dirtyCellKey]
		if bucket ~= nil then
			for entityId in bucket do
				affectedEntitySet[entityId] = true
			end
		end
	end

	for entityId in affectedEntitySet do
		table.insert(affectedEntities, entityId)
	end

	return affectedEntitySet, affectedEntities
end

function MovementService:_BuildFlowSeparationSolveSet(
	candidateEntities: { number },
	sepConfig: any
): ({ [number]: boolean }, { number })
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local solveEntitySet: { [number]: boolean } = {}
	local solveEntities: { number } = {}
	if not self:_UseIsolationSkip(sepConfig) then
		for _, entityId in ipairs(candidateEntities) do
			local entityState = runtime.EntityStateById[entityId]
			if entityState ~= nil and entityState.Active and entityState.Position ~= nil then
				solveEntitySet[entityId] = true
				table.insert(solveEntities, entityId)
			end
		end
		return solveEntitySet, solveEntities
	end

	local isolationRadius = self:_GetIsolationSkipRadiusStuds(sepConfig)
	local cellWidthStuds = runtime.CellWidthStuds
	for _, entityId in ipairs(candidateEntities) do
		local entityState = runtime.EntityStateById[entityId]
		local hasNearbyNeighbor = false
		if entityState ~= nil and entityState.Active and entityState.Position ~= nil and entityState.FlatPosition ~= nil then
			local checkedNeighbors: { [number]: boolean } = {}
			_ForEachCoveredSeparationCell(entityState.FlatPosition, isolationRadius, cellWidthStuds, function(gx: number, gz: number)
				if hasNearbyNeighbor then
					return
				end

				local bucket = runtime.BucketsByCell[_PackedSeparationCellKey(gx, gz)]
				if bucket == nil then
					return
				end

				for otherEntityId in bucket do
					if otherEntityId ~= entityId and not checkedNeighbors[otherEntityId] then
						checkedNeighbors[otherEntityId] = true
						local otherState = runtime.EntityStateById[otherEntityId]
						if otherState ~= nil and otherState.Active and otherState.Position ~= nil then
							if _XZDistance(entityState.Position, otherState.Position) <= isolationRadius then
								hasNearbyNeighbor = true
								return
							end
						end
					end
				end
			end)
		end

		if hasNearbyNeighbor then
			solveEntitySet[entityId] = true
			table.insert(solveEntities, entityId)
		end
	end

	return solveEntitySet, solveEntities
end

function MovementService:_RecomputeDirtyFlowSeparation(sepConfig: any)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	if next(runtime.DirtyEntities) == nil and next(runtime.DirtyCells) == nil then
		self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
		self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
		return
	end

	local affectedEntitySet, affectedEntities = self:_CollectFlowSeparationAffectedEntities()
	local candidateCellSet: { [number]: boolean } = {}
	local recomputedEntitySet: { [number]: boolean } = {}
	local recomputedEntities: { number } = {}

	self:_IncrementFastFlowProfileCounter("DirtyEntitiesProcessed", #affectedEntities)
	self:_IncrementFastFlowProfileCounter("DirtyCellsProcessed", self:_CountTableEntries(runtime.DirtyCells))

	for _, entityId in ipairs(affectedEntities) do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil then
			for _, coveredCell in ipairs(entityState.CoveredCells) do
				candidateCellSet[coveredCell.Key] = true
			end
		end
	end

	for candidateCellKey in candidateCellSet do
		local bucket = runtime.BucketsByCell[candidateCellKey]
		if bucket ~= nil then
			for entityId in bucket do
				if not recomputedEntitySet[entityId] then
					recomputedEntitySet[entityId] = true
					table.insert(recomputedEntities, entityId)
				end
			end
		end
	end

	for _, entityId in ipairs(recomputedEntities) do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil then
			entityState.Separation = Vector2.zero
		end
		runtime.ActiveSolveEntities[entityId] = nil
	end

	local activeSolveEntitySet, activeSolveEntities = self:_BuildFlowSeparationSolveSet(recomputedEntities, sepConfig)
	for _, entityId in ipairs(activeSolveEntities) do
		runtime.ActiveSolveEntities[entityId] = true
	end

	local kForce = if type(sepConfig.KForce) == "number" then sepConfig.KForce else 80
	local minSeparationDistance = if type(sepConfig.MinSeparationDistance) == "number" then sepConfig.MinSeparationDistance else 1e-4
	local denseFallbackEntitySet: { [number]: boolean } = {}

	if self:_UseDenseCellFallback(sepConfig) then
		local denseCellThreshold = self:_GetDenseCellOccupancyThreshold(sepConfig)
		for candidateCellKey in candidateCellSet do
			local bucket = runtime.BucketsByCell[candidateCellKey]
			if bucket ~= nil then
				local activeCellEntities: { number } = {}
				for entityId in bucket do
					if activeSolveEntitySet[entityId] then
						table.insert(activeCellEntities, entityId)
					end
				end

				if #activeCellEntities > denseCellThreshold then
					self:_IncrementFastFlowProfileCounter("DenseCellsEncountered")
					self:_IncrementFastFlowProfileCounter("DenseCellFallbackActivations")

					local center = Vector2.zero
					for _, entityId in ipairs(activeCellEntities) do
						local entityState = runtime.EntityStateById[entityId]
						if entityState ~= nil and entityState.FlatPosition ~= nil then
							center += entityState.FlatPosition
							denseFallbackEntitySet[entityId] = true
						end
					end

					center = center / #activeCellEntities
					for _, entityId in ipairs(activeCellEntities) do
						local entityState = runtime.EntityStateById[entityId]
						if entityState ~= nil and entityState.FlatPosition ~= nil then
							local displacement = entityState.FlatPosition - center
							local distance = displacement.Magnitude
							if distance > minSeparationDistance then
								local crowdPressure = math.max(0, entityState.Radius * #activeCellEntities - distance)
								if crowdPressure > 0 then
									entityState.Separation += kForce * (displacement / distance) * crowdPressure
								end
							end
						end
					end
				end
			end
		end
	end

	local processedPairs: { [string]: boolean } = {}
	for candidateCellKey in candidateCellSet do
		local bucket = runtime.BucketsByCell[candidateCellKey]
		if bucket ~= nil then
			local cellEntities: { number } = {}
			for entityId in bucket do
				table.insert(cellEntities, entityId)
			end

			for index = 1, #cellEntities do
				local entityA = cellEntities[index]
				local entityStateA = runtime.EntityStateById[entityA]
				if entityStateA ~= nil and activeSolveEntitySet[entityA] and not denseFallbackEntitySet[entityA] then
					for otherIndex = index + 1, #cellEntities do
						local entityB = cellEntities[otherIndex]
						if activeSolveEntitySet[entityB] and not denseFallbackEntitySet[entityB] then
							local pairKey = string.format("%d:%d", math.min(entityA, entityB), math.max(entityA, entityB))
							if not processedPairs[pairKey] then
								processedPairs[pairKey] = true
								local entityStateB = runtime.EntityStateById[entityB]
								if entityStateB ~= nil and entityStateA.FlatPosition ~= nil and entityStateB.FlatPosition ~= nil then
									local displacement = entityStateA.FlatPosition - entityStateB.FlatPosition
									local distance = displacement.Magnitude
									local penetration = entityStateA.Radius + entityStateB.Radius - distance
									if penetration > 0 and distance > minSeparationDistance then
										local separationDelta = kForce * (displacement / distance) * penetration * penetration
										entityStateA.Separation += separationDelta
										entityStateB.Separation -= separationDelta
										self:_IncrementFastFlowProfileCounter("LocalPairSolves")
									end
								end
							end
						end
					end
				end
			end
		end
	end

	for _, entityId in ipairs(recomputedEntities) do
		local entityState = runtime.EntityStateById[entityId]
		if entityState ~= nil and entityState.NearGoalScale < 1 then
			entityState.Separation *= entityState.NearGoalScale
		end
	end

	table.clear(runtime.DirtyEntities)
	table.clear(runtime.DirtyCells)
	self:_SetFastFlowProfileCounter("TrackedFlowEntities", self:_CountTableEntries(runtime.TrackedFlowEntities))
	self:_SetFastFlowProfileCounter("ActiveSeparationEntities", self:_CountTableEntries(runtime.ActiveSolveEntities))
end

function MovementService:_GetFlowSoftSeparationXZ(entity: number, sepConfig: any): Vector2
	self:_RecomputeDirtyFlowSeparation(sepConfig)
	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local entityState = runtime.EntityStateById[entity]
	return if entityState ~= nil then entityState.Separation else Vector2.zero
end

function MovementService:_ShouldSettleIntoClump(
	entity: number,
	goalKey: string,
	entityPosition: Vector3,
	sepConfig: any
): boolean
	if sepConfig == nil or sepConfig.ClumpIdleEnabled ~= true then
		return false
	end

	local runtime = self:_GetOrCreateFlowSeparationRuntime()
	local ownState = runtime.EntityStateById[entity]
	if ownState == nil or ownState.Radius <= 0 or ownState.GoalKey ~= goalKey or runtime.CellWidthStuds <= 0 then
		return false
	end

	local touchPadding = self:_GetFlowClumpTouchPaddingStuds(sepConfig)
	local checkedNeighbors: { [number]: boolean } = {}
	local didTouchSettledNeighbor = false

	_ForEachCoveredSeparationCell(_FlatXZ(entityPosition), ownState.Radius + touchPadding, runtime.CellWidthStuds, function(gx: number, gz: number)
		if didTouchSettledNeighbor then
			return
		end

		local bucket = runtime.BucketsByCell[_PackedSeparationCellKey(gx, gz)]
		if bucket == nil then
			return
		end

		for otherEntity in bucket do
			if otherEntity ~= entity and not checkedNeighbors[otherEntity] then
				checkedNeighbors[otherEntity] = true
				local otherState = runtime.EntityStateById[otherEntity]
				if otherState ~= nil and otherState.Settled and otherState.GoalKey == goalKey and otherState.Position ~= nil then
					local touchDistance = ownState.Radius + otherState.Radius + touchPadding
					if _XZDistance(entityPosition, otherState.Position) <= touchDistance then
						didTouchSettledNeighbor = true
						return
					end
				end
			end
		end
	end)

	return didTouchSettledNeighbor
end

function MovementService:_HandleGoalChange(
	entity: number,
	movementState: TFlowMovementState,
	goalPosition: Vector3
): (boolean, string?)
	if (goalPosition - movementState.GoalSnapshot).Magnitude <= GOAL_POSITION_EPSILON then
		return true, nil
	end

	local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, false)
	if goalKey == nil or goalWorldSample == nil then
		return false, if reason ~= nil then reason else "FastFlowGenerateFailed"
	end

	movementState.GoalSnapshot = goalPosition
	movementState.GoalKey = goalKey
	movementState.GoalWorldSample = goalWorldSample
	return true, nil
end

function MovementService:_HandleFlowArrival(
	entity: number,
	movementState: TFlowMovementState,
	entityPosition: Vector3,
	goalPosition: Vector3,
	sepConfig: any
): ("Continue" | "Settled" | "Success")
	if _XZDistance(goalPosition, entityPosition) <= self:_GetFlowArrivalThreshold() then
		self:_StopHumanoid(entity)
		self:_ClearMovementRuntimeState(entity, movementState.GoalKey)
		return "Success"
	end

	if self._flowSettledByEntity[entity] == true then
		self:_StopHumanoid(entity)
		return "Settled"
	end

	if _XZDistance(goalPosition, entityPosition) > self:_GetFlowClumpIdleRadiusStuds(sepConfig) then
		return "Continue"
	end

	if self:_ShouldSettleIntoClump(entity, movementState.GoalKey, entityPosition, sepConfig) then
		self:_MarkFlowSettled(entity, movementState.GoalKey)
		self:_StopHumanoid(entity)
		return "Settled"
	end

	return "Continue"
end

function MovementService:_ResolveFlowSteering(
	entity: number,
	movementState: TFlowMovementState,
	entityPosition: Vector3,
	goalPosition: Vector3,
	sepConfig: any
): (Vector3?, string?)
	local pathfinderForMerge, mapping = self:_ResolveFastFlowRuntime()
	if mapping == nil then
		return nil, "FastFlowNotConfigured"
	end

	local sharedEntry = self:_GetSharedFlowfieldEntry(movementState.GoalKey)
	if sharedEntry == nil then
		local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, true)
		if goalKey == nil or goalWorldSample == nil then
			return nil, if reason ~= nil then reason else "MissingFlowfield"
		end
		movementState.GoalKey = goalKey
		movementState.GoalWorldSample = goalWorldSample
		sharedEntry = self:_GetSharedFlowfieldEntry(goalKey)
		if sharedEntry == nil then
			return nil, "MissingFlowfield"
		end
	end

	local steering = FastFlowHelper.GetSteeringWorldXZ(sharedEntry.Flowfield, entityPosition, mapping)
	if steering == nil and pathfinderForMerge ~= nil then
		self:_IncrementFastFlowProfileCounter("MergeAttempts")
		local merged = FastFlowHelper.MergeFlowfieldWorld(pathfinderForMerge, sharedEntry.Flowfield, entityPosition, mapping)
		if merged ~= nil then
			sharedEntry.Flowfield = merged
			steering = FastFlowHelper.GetSteeringWorldXZ(sharedEntry.Flowfield, entityPosition, mapping)
		end
	end

	if steering ~= nil then
		return steering, nil
	end

	local now = os.clock()
	local repairAfter = self._flowSteeringRepairAtClockByEntity[entity] or 0
	if now < repairAfter then
		return nil, nil
	end

	self._flowSteeringRepairAtClockByEntity[entity] = now + self:_GetSharedFlowfieldRefreshCooldownSeconds(sepConfig)
	local goalKey, goalWorldSample, reason = self:_AttachEntityToFlowGoal(entity, goalPosition, true)
	if goalKey == nil or goalWorldSample == nil then
		return nil, if reason ~= nil then reason else "FastFlowGenerateFailed"
	end

	movementState.GoalKey = goalKey
	movementState.GoalWorldSample = goalWorldSample

	local refreshedEntry = self:_GetSharedFlowfieldEntry(goalKey)
	if refreshedEntry == nil then
		return nil, "MissingFlowfield"
	end

	return FastFlowHelper.GetSteeringWorldXZ(refreshedEntry.Flowfield, entityPosition, mapping), nil
end

function MovementService:_TickFlow(
	entity: number,
	movementState: TFlowMovementState
): ("Running" | "Success" | "Fail", string?)
	local pathState = self._enemyEntityFactory:GetPathState(entity)
	local goalPosition = if pathState ~= nil then pathState.GoalPosition else nil
	if goalPosition == nil then
		self:StopMovement(entity)
		return "Fail", "MissingGoalPosition"
	end

	local entityPosition = self:_GetEntityPosition(entity)
	if entityPosition == nil then
		self:StopMovement(entity)
		return "Fail", "MissingModelPosition"
	end

	-- Reattach shared flow state when the goal changes.
	local handledGoalChange, goalChangeReason = self:_HandleGoalChange(entity, movementState, goalPosition)
	if not handledGoalChange then
		self:StopMovement(entity)
		return "Fail", if goalChangeReason ~= nil then goalChangeReason else "FastFlowGenerateFailed"
	end

	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
	self:_RefreshFlowSeparationEntitySpatialState(entity, entityPosition)

	-- Stop or settle before doing any new steering work.
	local arrivalResult = self:_HandleFlowArrival(entity, movementState, entityPosition, goalPosition, sepConfig)
	if arrivalResult == "Success" then
		return "Success", nil
	end

	local humanoid = self:_GetHumanoid(entity)
	if humanoid == nil then
		self:StopMovement(entity)
		return "Fail", "MissingHumanoid"
	end

	if arrivalResult == "Settled" then
		self._enemyEntityFactory:SetPathMoving(entity, true)
		return "Running", nil
	end

	-- Resolve steering from the shared goal-cell flowfield.
	local steering, steeringReason = self:_ResolveFlowSteering(entity, movementState, entityPosition, goalPosition, sepConfig)
	if steering == nil and steeringReason ~= nil then
		self:StopMovement(entity)
		return "Fail", steeringReason
	end

	local walkSpeed = self:_ApplyCurrentMoveSpeed(entity, sepConfig)
	local useSoftSeparation = sepConfig ~= nil and sepConfig.Enabled == true

	-- Blend shared steering with local separation for still-active movers.
	if useSoftSeparation then
		local flowXZ = if steering ~= nil then Vector2.new(steering.X, steering.Z) * walkSpeed else Vector2.zero
		local sepXZ = self:_GetFlowSoftSeparationXZ(entity, sepConfig)
		local velXZ = flowXZ + sepXZ
		velXZ = _ClampVector2Magnitude(velXZ, walkSpeed)
		local velAlpha = if type(sepConfig.VelAlpha) == "number" then math.clamp(sepConfig.VelAlpha, 0, 1) else 0.15
		local previousVel = self._flowVelByEntity[entity] or Vector2.zero
		velXZ = previousVel * (1 - velAlpha) + velXZ * velAlpha
		self._flowVelByEntity[entity] = velXZ

		local moveDirection = Vector3.new(velXZ.X, 0, velXZ.Y)
		if moveDirection.Magnitude > 0.05 then
			humanoid:Move(moveDirection.Unit)
		else
			humanoid:Move(Vector3.zero)
		end
	else
		if steering == nil then
			humanoid:Move(Vector3.zero)
		else
			humanoid:Move(steering)
		end
	end

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

return MovementService
