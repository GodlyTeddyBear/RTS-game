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

local function _SeparationCellKey(gx: number, gz: number): string
	return string.format("%d,%d", gx, gz)
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

type EnemyMovementMode = EnemyTypes.EnemyMovementMode

type TPathMovementState = {
	Mode: "Path",
	Promise: any,
}

type TFlowMovementState = {
	Mode: "Flow",
	Flowfield: any,
	GoalSnapshot: Vector3,
}

type TMovementState = TPathMovementState | TFlowMovementState

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
	self._fastFlowPathfinder = nil
	self._fastFlowMapping = nil
	self._lastFastFlowEndpointDiagnosticKey = nil :: string?
	self._flowVelByEntity = {} :: { [number]: Vector2 }
	self._flowSteeringRepairAtClockByEntity = {} :: { [number]: number }
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

function MovementService:ConfigureFlowfieldDebugRenderer(renderer: ((any, FastFlowHelper.TFlowGridMapping, Vector3) -> ())?)
	self._flowfieldDebugRenderer = renderer
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
		self:_StopHumanoid(entity)
	end

	self._movementByEntity[entity] = nil
	self._flowVelByEntity[entity] = nil
	self._flowSteeringRepairAtClockByEntity[entity] = nil
	self._enemyEntityFactory:SetPathMoving(entity, false)
	if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
		self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
	end
end

function MovementService:CleanupAll()
	local entities = {}
	for entityId in self._movementByEntity do
		table.insert(entities, entityId)
	end

	for _, entityId in ipairs(entities) do
		self:StopMovement(entityId)
	end

	table.clear(self._flowVelByEntity)
	table.clear(self._flowSteeringRepairAtClockByEntity)
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

function MovementService:_GetEntityModel(entity: number): Model?
	local modelRef = self._enemyEntityFactory:GetModelRef(entity)
	return if modelRef ~= nil then modelRef.Model else nil
end

function MovementService:_GetEntityPosition(entity: number): Vector3?
	local model = self:_GetEntityModel(entity)
	local primaryPart = if model ~= nil then model.PrimaryPart else nil
	return if primaryPart ~= nil then primaryPart.Position else nil
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

function MovementService:_GenerateFlowfieldForEntity(
	entity: number,
	goalPosition: Vector3,
	usePrunedStart: boolean?
): (any?, string?)
	local pathfinder, mapping = self:_ResolveFastFlowRuntime()
	if pathfinder == nil or mapping == nil then
		return nil, "FastFlowNotConfigured"
	end

	local entityPosition = self:_GetEntityPosition(entity)
	if entityPosition == nil then
		return nil, "MissingModelPosition"
	end

	local prune = if usePrunedStart == nil then true else usePrunedStart
	local starts = if prune then { entityPosition } else nil
	local flowfield = FastFlowHelper.GenerateFlowfieldWorld(pathfinder, goalPosition, mapping, starts)
	if flowfield == nil then
		self:_EmitFastFlowEndpointDiagnostic(entity, entityPosition, goalPosition, pathfinder, mapping)
		return nil, "FastFlowGenerateFailed"
	end

	return flowfield, nil
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
	if renderer == nil or mapping == nil then
		return
	end

	renderer(flowfield, mapping, goalPosition)
end

function MovementService:_StartFlow(entity: number, goalPosition: Vector3): (boolean, string?)
	local flowfield, reason = self:_GenerateFlowfieldForEntity(entity, goalPosition)
	if flowfield == nil then
		return false, reason
	end

	self._movementByEntity[entity] = {
		Mode = "Flow",
		Flowfield = flowfield,
		GoalSnapshot = goalPosition,
	}
	self._enemyEntityFactory:SetPathMoving(entity, true)
	self:_EmitFlowfieldDebug(flowfield, goalPosition)
	return true, nil
end

function MovementService:_GetFlowArrivalThreshold(): number
	local configuredThreshold = BoidsConfig.ArrivalThreshold
	if type(configuredThreshold) ~= "number" or configuredThreshold <= 0 then
		return 2.75
	end
	return configuredThreshold
end

function MovementService:_GetAgentRadiusStuds(entity: number): number
	local params = self:_GetAgentParams(entity)
	local agentRadius = params.AgentRadius
	if type(agentRadius) == "number" and agentRadius > 0 then
		return agentRadius
	end
	return 2
end

function MovementService:_CollectFlowMovementEntities(): { number }
	local flowEntities: { number } = {}
	for entityId, movementState in self._movementByEntity do
		if movementState.Mode == "Flow" then
			table.insert(flowEntities, entityId)
		end
	end
	return flowEntities
end

function MovementService:_CollectFlowEntityPositions(flowEntities: { number }): { [number]: Vector3 }
	local positions: { [number]: Vector3 } = {}
	for _, entityId in ipairs(flowEntities) do
		local worldPosition = self:_GetEntityPosition(entityId)
		if worldPosition ~= nil then
			positions[entityId] = worldPosition
		end
	end
	return positions
end

function MovementService:_GetFlowSeparationHashCellWidth(flowEntities: { number }, positions: { [number]: Vector3 }): number
	local maxRadius = 0
	for _, entityId in ipairs(flowEntities) do
		if positions[entityId] ~= nil then
			local radius = self:_GetAgentRadiusStuds(entityId)
			if radius > maxRadius then
				maxRadius = radius
			end
		end
	end
	if maxRadius <= 0 then
		maxRadius = 2
	end
	return maxRadius * 2
end

function MovementService:_BuildFlowSeparationBuckets(
	flowEntities: { number },
	positions: { [number]: Vector3 },
	cellWidthStuds: number
): { [string]: { number } }
	local buckets: { [string]: { number } } = {}
	if cellWidthStuds <= 0 then
		return buckets
	end

	for _, entityId in ipairs(flowEntities) do
		local worldPosition = positions[entityId]
		if worldPosition ~= nil then
			local radius = self:_GetAgentRadiusStuds(entityId)
			local offset = Vector2.new(radius, radius)
			local flat = Vector2.new(worldPosition.X, worldPosition.Z)
			local corner0X = math.round((flat.X - offset.X) / cellWidthStuds)
			local corner0Z = math.round((flat.Y - offset.Y) / cellWidthStuds)
			local corner1X = math.round((flat.X + offset.X) / cellWidthStuds)
			local corner1Z = math.round((flat.Y + offset.Y) / cellWidthStuds)
			local minGx = math.min(corner0X, corner1X)
			local maxGx = math.max(corner0X, corner1X)
			local minGz = math.min(corner0Z, corner1Z)
			local maxGz = math.max(corner0Z, corner1Z)

			for gx = minGx, maxGx do
				for gz = minGz, maxGz do
					local key = _SeparationCellKey(gx, gz)
					local cellList = buckets[key]
					if cellList == nil then
						cellList = {}
						buckets[key] = cellList
					end
					table.insert(cellList, entityId)
				end
			end
		end
	end

	return buckets
end

function MovementService:_ComputeFlowSoftSeparationXZ(selfEntity: number, selfWorld: Vector3, sepConfig: any): Vector2
	local kForce = if type(sepConfig.KForce) == "number" then sepConfig.KForce else 80
	local minSeparationDistance = if type(sepConfig.MinSeparationDistance) == "number" then sepConfig.MinSeparationDistance else 1e-4

	local flowEntities = self:_CollectFlowMovementEntities()
	local positions = self:_CollectFlowEntityPositions(flowEntities)
	local cellWidthStuds = self:_GetFlowSeparationHashCellWidth(flowEntities, positions)
	local buckets = self:_BuildFlowSeparationBuckets(flowEntities, positions, cellWidthStuds)

	local selfRadius = self:_GetAgentRadiusStuds(selfEntity)
	local selfFlat = Vector2.new(selfWorld.X, selfWorld.Z)
	local offset = Vector2.new(selfRadius, selfRadius)

	local sep = Vector2.zero
	local dedupe: { [number]: boolean } = {}

	if cellWidthStuds <= 0 then
		return sep
	end

	local corner0X = math.round((selfFlat.X - offset.X) / cellWidthStuds)
	local corner0Z = math.round((selfFlat.Y - offset.Y) / cellWidthStuds)
	local corner1X = math.round((selfFlat.X + offset.X) / cellWidthStuds)
	local corner1Z = math.round((selfFlat.Y + offset.Y) / cellWidthStuds)
	local minGx = math.min(corner0X, corner1X)
	local maxGx = math.max(corner0X, corner1X)
	local minGz = math.min(corner0Z, corner1Z)
	local maxGz = math.max(corner0Z, corner1Z)

	for gx = minGx, maxGx do
		for gz = minGz, maxGz do
			local cellList = buckets[_SeparationCellKey(gx, gz)]
			if cellList ~= nil then
				for _, otherEntity in ipairs(cellList) do
					if otherEntity ~= selfEntity and not dedupe[otherEntity] then
						dedupe[otherEntity] = true
						local otherPosition = positions[otherEntity]
						if otherPosition ~= nil then
							local otherRadius = self:_GetAgentRadiusStuds(otherEntity)
							local otherFlat = Vector2.new(otherPosition.X, otherPosition.Z)
							local displacement = selfFlat - otherFlat
							local distance = displacement.Magnitude
							local pairSpan = selfRadius + otherRadius
							local penetration = pairSpan - distance

							if penetration > 0 and distance > minSeparationDistance then
								sep += kForce * (displacement / distance) * penetration * penetration
							end
						end
					end
				end
			end
		end
	end

	return sep
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

	if (goalPosition - movementState.GoalSnapshot).Magnitude > GOAL_POSITION_EPSILON then
		local flowfield, reason = self:_GenerateFlowfieldForEntity(entity, goalPosition)
		if flowfield == nil then
			self:StopMovement(entity)
			return "Fail", if reason ~= nil then reason else "FastFlowGenerateFailed"
		end
		movementState.Flowfield = flowfield
		movementState.GoalSnapshot = goalPosition
		self:_EmitFlowfieldDebug(flowfield, goalPosition)
	end

	if (goalPosition - entityPosition).Magnitude <= self:_GetFlowArrivalThreshold() then
		self:StopMovement(entity)
		return "Success", nil
	end

	local humanoid = self:_GetHumanoid(entity)
	if humanoid == nil then
		self:StopMovement(entity)
		return "Fail", "MissingHumanoid"
	end

	local pathfinderForMerge, mapping = self:_ResolveFastFlowRuntime()
	if mapping == nil then
		self:StopMovement(entity)
		return "Fail", "FastFlowNotConfigured"
	end

	if movementState.Flowfield == nil then
		local repairedFlowfield, repairReason = self:_GenerateFlowfieldForEntity(entity, goalPosition, true)
		if repairedFlowfield == nil then
			self:StopMovement(entity)
			return "Fail", if repairReason ~= nil then repairReason else "MissingFlowfield"
		end
		movementState.Flowfield = repairedFlowfield
		self:_EmitFlowfieldDebug(repairedFlowfield, goalPosition)
	end

	local flowfield = movementState.Flowfield
	local steering = FastFlowHelper.GetSteeringWorldXZ(flowfield, entityPosition, mapping)
	if steering == nil and pathfinderForMerge ~= nil then
		local merged = FastFlowHelper.MergeFlowfieldWorld(pathfinderForMerge, flowfield, entityPosition, mapping)
		if merged ~= nil then
			movementState.Flowfield = merged
			flowfield = merged
			steering = FastFlowHelper.GetSteeringWorldXZ(flowfield, entityPosition, mapping)
		end
	end

	if steering == nil then
		local now = os.clock()
		local repairAfter = self._flowSteeringRepairAtClockByEntity[entity] or 0
		if now >= repairAfter then
			self._flowSteeringRepairAtClockByEntity[entity] = now + 0.35
			local regenFlowfield, _regenReason = self:_GenerateFlowfieldForEntity(entity, goalPosition, false)
			if regenFlowfield ~= nil then
				movementState.Flowfield = regenFlowfield
				flowfield = regenFlowfield
				self:_EmitFlowfieldDebug(regenFlowfield, goalPosition)
				steering = FastFlowHelper.GetSteeringWorldXZ(flowfield, entityPosition, mapping)
			end
		end
	end

	local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
	local useSoftSeparation = sepConfig ~= nil and sepConfig.Enabled == true

	local walkSpeed = humanoid.WalkSpeed
	if type(walkSpeed) ~= "number" or walkSpeed <= 0 then
		walkSpeed = 16
	end

	if useSoftSeparation then
		local flowXZ = if steering ~= nil then Vector2.new(steering.X, steering.Z) * walkSpeed else Vector2.zero
		local sepXZ = self:_ComputeFlowSoftSeparationXZ(entity, entityPosition, sepConfig)
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
