--!strict

--[=[
    @class EnemyCombatAdapterService
    Bridges enemy entities into the combat runtime and wires enemy-specific targeting, movement, and damage adapters.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local FastFlow = require(ServerStorage.Utilities.FastFlow)
local FastFlowHelper = require(ServerStorage.Utilities.FastFlowHelper)
local RuntimeFactCache = require(ServerStorage.Utilities.ContextUtilities.RuntimeFactCache)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)
local EnemyRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.EnemyRuntimeProfiles)
local EnemyFactsResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyFactsResolverFactory)
local EnemyFactoryProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyFactoryProxyResolverFactory)
local EnemyGoalAssignmentResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyGoalAssignmentResolverFactory)
local EnemyHitTargetResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyHitTargetResolverFactory)
local EnemyHitboxProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyHitboxProxyResolverFactory)
local EnemyMeleeResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyMeleeResolverFactory)
local EnemyMovementProxyResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyMovementProxyResolverFactory)
local EnemyPerceptionResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyPerceptionResolverFactory)
local EnemyTargetingResolverFactory = require(script.Parent.Parent.Runtime.Resolvers.EnemyTargetingResolverFactory)

type EnemyRole = EnemyTypes.EnemyRole
type EnemyRoleConfig = EnemyTypes.EnemyRoleConfig
type GridSpec = WorldTypes.GridSpec
type Tile = WorldTypes.Tile

local EnemySemanticRequirements = table.freeze({
	FactsDependOnPolling = true,
	AttributesDependOnProjection = true,
})

local EnemyRuntimeBinding = table.freeze({
	ServiceField = "_syncService",
	PollPhase = "EnemySync",
	SyncPhase = "EnemySync",
})
local FASTFLOW_ARROW_FOLDER_NAME = "FastFlowArrowParts"
local FLOWFIELD_DIRECTION_EPSILON_SQUARED = 1e-6
local POSITION_INVALIDATION_EPSILON = 1e-4
local FACT_CACHE_REFRESH_INTERVAL_SECONDS = 0.2
local FACT_GROUP_CACHE_REFRESH_INTERVAL_SECONDS = 1
local CHEAP_FACT_GROUP_NAVIGATION = "Navigation"
local CHEAP_FACT_GROUP_SPATIAL_COMBAT = "SpatialCombat"
local CHEAP_FACT_GROUP_STATUS = "Status"
local FLEE_THRESHOLD = 0.2

local function _GetGridSubdivisions(): number
	local gridConfig = CombatMovementConfig.FASTFLOW_GRID
	local configured = if gridConfig ~= nil then gridConfig.Subdivisions else nil
	if type(configured) ~= "number" then
		return 1
	end

	return math.max(1, math.floor(configured))
end

local function _GetGridOriginWorld(spec: GridSpec): Vector3
	local midCol = math.floor((spec.GridCols + 1) * 0.5)
	local midRow = math.floor((spec.GridRows + 1) * 0.5)
	local localX = -spec.GridSize.X * 0.5 + spec.TileSize * 0.5 + (midCol - 1) * spec.TileSize
	local localZ = -spec.GridSize.Z * 0.5 + spec.TileSize * 0.5 + (midRow - 1) * spec.TileSize
	return spec.GridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

local function _HasPositionChanged(previousPosition: Vector3?, currentPosition: Vector3?): boolean
	if previousPosition == nil or currentPosition == nil then
		return previousPosition ~= currentPosition
	end

	return (currentPosition - previousPosition).Magnitude > POSITION_INVALIDATION_EPSILON
end

local function _ResolveHealthPct(health: { Current: number, Max: number }?): number
	if health == nil or health.Max <= 0 then
		return 1
	end

	return math.clamp(health.Current / health.Max, 0, 1)
end

local function _BuildFlowGridMapping(spec: GridSpec, subdivisions: number): FastFlowHelper.TFlowGridMapping
	local midCol = math.floor((spec.GridCols + 1) * 0.5)
	local midRow = math.floor((spec.GridRows + 1) * 0.5)
	local minColCell = (-(midCol - 1)) * subdivisions
	local maxColCell = (spec.GridCols - midCol) * subdivisions
	local minRowCell = (-(midRow - 1)) * subdivisions
	local maxRowCell = (spec.GridRows - midRow) * subdivisions
	local subCellStart = -math.floor((subdivisions - 1) * 0.5)
	local subCellEnd = subCellStart + subdivisions - 1
	return {
		OriginWorld = _GetGridOriginWorld(spec),
		CellWidthStuds = spec.TileSize / subdivisions,
		GridHalfSize = math.max(
			math.abs(minColCell + subCellStart),
			math.abs(maxColCell + subCellEnd),
			math.abs(minRowCell + subCellStart),
			math.abs(maxRowCell + subCellEnd)
		),
	}
end

local function _IsTileBlockedForFlow(tile: Tile): boolean
	return tile.Zone == "blocked" or tile.IsPlacementProhibited == true
end

local function _BuildWallsFromTiles(spec: GridSpec, tiles: { Tile }): (any, FastFlowHelper.TFlowGridMapping)
	local subdivisions = _GetGridSubdivisions()
	local mapping = _BuildFlowGridMapping(spec, subdivisions)
	local walls = FastFlow.Grid.New(mapping.GridHalfSize, true)
	local subCellStart = -math.floor((subdivisions - 1) * 0.5)
	local subCellEnd = subCellStart + subdivisions - 1

	for _, tile in ipairs(tiles) do
		if tile.Coord.GridId == spec.GridId then
			local centerCell = FastFlowHelper.WorldXZToGridCell(tile.WorldPos, mapping)
			local isBlocked = _IsTileBlockedForFlow(tile)
			for dx = subCellStart, subCellEnd do
				for dy = subCellStart, subCellEnd do
					local cell = Vector2.new(centerCell.X + dx, centerCell.Y + dy)
					if walls:IsCellInBounds(cell) then
						walls:SetCell(cell, if isBlocked then true else nil)
					end
				end
			end
		end
	end

	return walls, mapping
end

local EnemyCombatAdapterService = {}
EnemyCombatAdapterService.__index = EnemyCombatAdapterService

-- ── Public ────────────────────────────────────────────────────────────────────

-- Creates a new enemy combat adapter service with deferred combat-service wiring.
--[=[
    @within EnemyCombatAdapterService
    Creates a new enemy combat adapter service.
    @return EnemyCombatAdapterService -- Service instance used to register enemy combat actors.
]=]
function EnemyCombatAdapterService.new()
	local self = setmetatable({}, EnemyCombatAdapterService)
	self._configuredCombatServices = false
	self._runtimeOwner = nil
	self._isFastFlowConfigured = false
	self._cachedFactsByEntity = {}
	self._cachedExecutorServicesByEntity = {}
	return self
end

-- Resolves the entity factories needed to build enemy actor adapters.
--[=[
    @within EnemyCombatAdapterService
    Resolves the enemy context dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function EnemyCombatAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
	self._instanceFactory = registry:Get("EnemyInstanceFactory")
end

-- Caches cross-context references and wires combat services once.
--[=[
    @within EnemyCombatAdapterService
    Resolves the combat, structure, and base dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function EnemyCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._structureContext = registry:Get("StructureContext")
	self._baseContext = registry:Get("BaseContext")
	self._worldContext = registry:Get("WorldContext")
	self._structureEntityFactory = self._structureContext:GetEntityFactory().value
	self._structureInstanceFactory = self._structureContext:GetInstanceFactory().value
	self._baseEntityFactory = self._baseContext:GetEntityFactory().value
	self._baseInstanceFactory = self._baseContext:GetInstanceFactory().value
	self._combatServices = self._combatContext:GetCombatRuntimeServices().value
	self._targetingResolver = EnemyTargetingResolverFactory.Create({
		BaseEntityFactory = self._baseEntityFactory,
		StructureEntityFactory = self._structureEntityFactory,
		BaseInstanceFactory = self._baseInstanceFactory,
		StructureInstanceFactory = self._structureInstanceFactory,
	})
	self._factsResolver = EnemyFactsResolverFactory.Create({
		EnemyEntityFactory = self._entityFactory,
		TargetingResolver = self._targetingResolver,
	})
	self._perceptionResolver = EnemyPerceptionResolverFactory.Create({
		TargetingResolver = self._targetingResolver,
	})
	self._movementProxyResolver = EnemyMovementProxyResolverFactory.Create({
		MovementService = self._combatServices.MovementService,
		EnemyEntityFactory = self._entityFactory,
	})
	self._enemyFactoryProxyResolver = EnemyFactoryProxyResolverFactory.Create({
		EnemyEntityFactory = self._entityFactory,
	})
	self._hitboxProxyResolver = EnemyHitboxProxyResolverFactory.Create({
		EnemyInstanceFactory = self._instanceFactory,
		HitboxService = self._combatServices.HitboxService,
	})
	self._goalAssignmentResolver = EnemyGoalAssignmentResolverFactory.Create({
		BaseContext = self._baseContext,
		EnemyEntityFactory = self._entityFactory,
	})
	self:_ConfigureCombatServices()
end

function EnemyCombatAdapterService:_ResolveFastFlowConfiguration(): (any?, FastFlowHelper.TFlowGridMapping?)
	if self._worldContext == nil then
		return nil, nil
	end

	local gridSpecsResult = self._worldContext:GetGridSpecList()
	if not gridSpecsResult.success then
		return nil, nil
	end

	local gridSpecs = gridSpecsResult.value :: { GridSpec }
	-- FastFlow currently supports one active authored placement grid; WorldGridRuntimeService sorts by GridId.
	local selectedGrid = gridSpecs[1]
	if selectedGrid == nil then
		return nil, nil
	end

	local allTilesResult = self._worldContext:GetAllTilesView()
	if not allTilesResult.success then
		return nil, nil
	end

	local walls, mapping = _BuildWallsFromTiles(selectedGrid, allTilesResult.value :: { Tile })
	return FastFlowHelper.CreatePathfinderFromWalls(walls), mapping
end

function EnemyCombatAdapterService:_EnsureFastFlowConfigured()
	if self._isFastFlowConfigured then
		return
	end

	local fastFlowPathfinder, fastFlowMapping = self:_ResolveFastFlowConfiguration()
	if fastFlowPathfinder == nil or fastFlowMapping == nil then
		return
	end

	self._combatServices.MovementService:ConfigureFastFlow(fastFlowPathfinder, fastFlowMapping)
	self:_VisualizeFastFlow(fastFlowPathfinder, fastFlowMapping)
	self._isFastFlowConfigured = true
end

function EnemyCombatAdapterService:_ResetFastFlowConfiguration()
	self._combatServices.MovementService:ResetFastFlowRuntime()
	self._combatServices.MovementService:ConfigureFastFlow(nil, nil)
	self._isFastFlowConfigured = false
end

function EnemyCombatAdapterService:WarmFastFlowForRun(): boolean
	self:_ResetFastFlowConfiguration()
	self:_EnsureFastFlowConfigured()
	return self._isFastFlowConfigured == true
end

function EnemyCombatAdapterService:_VisualizeFastFlow(pathfinder: any, mapping: FastFlowHelper.TFlowGridMapping)
	local visualizeConfig = CombatMovementConfig.FASTFLOW_VISUALIZATION
	local visualFolder = workspace:FindFirstChild("VisualizeParts")
	if visualFolder ~= nil and visualFolder:IsA("Folder") then
		visualFolder:ClearAllChildren()
	end
	if visualizeConfig == nil or visualizeConfig.Enabled ~= true then
		return
	end

	pathfinder:Visualize(
		mapping.CellWidthStuds,
		mapping.OriginWorld.Y + visualizeConfig.YLevelOffset,
		visualizeConfig.ShowWalls,
		visualizeConfig.ShowCellGrid,
		visualizeConfig.ShowChunkGrid,
		visualizeConfig.ShowHPA
	)

	local offsetXZ = Vector3.new(mapping.OriginWorld.X, 0, mapping.OriginWorld.Z)
	local refreshedFolder = workspace:FindFirstChild("VisualizeParts")
	if refreshedFolder == nil or not refreshedFolder:IsA("Folder") then
		return
	end

	for _, child in ipairs(refreshedFolder:GetChildren()) do
		if child:IsA("BasePart") then
			child.CFrame += offsetXZ
		end
	end
end

function EnemyCombatAdapterService:_GetOrCreateArrowFolder(): Folder
	local existing = Workspace:FindFirstChild(FASTFLOW_ARROW_FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FASTFLOW_ARROW_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

function EnemyCombatAdapterService:_VisualizeFlowArrows(
	flowfield: any,
	mapping: FastFlowHelper.TFlowGridMapping,
	_goalPosition: Vector3
)
	local arrowConfig = CombatMovementConfig.FASTFLOW_ARROW_VISUALIZATION
	local folder = self:_GetOrCreateArrowFolder()
	folder:ClearAllChildren()
	if arrowConfig == nil or arrowConfig.Enabled ~= true then
		return
	end

	local sampleStep = math.max(1, math.floor(arrowConfig.SampleStepCells))
	local arrowWidth = math.max(0.05, arrowConfig.ArrowWidthStuds)
	local arrowLength = math.max(0.25, arrowConfig.ArrowLengthStuds)
	local maxArrows = math.max(1, math.floor(arrowConfig.MaxArrows))
	local halfSize = mapping.GridHalfSize

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { folder }

	local renderedArrows = 0
	for x = -halfSize, halfSize, sampleStep do
		for y = -halfSize, halfSize, sampleStep do
			if renderedArrows >= maxArrows then
				return
			end

			local cell = Vector2.new(x, y)
			local direction = flowfield:GetDirection(cell)
			if direction ~= nil then
				local magnitudeSquared = direction.X * direction.X + direction.Y * direction.Y
				if magnitudeSquared > FLOWFIELD_DIRECTION_EPSILON_SQUARED then
					local magnitude = math.sqrt(magnitudeSquared)
					local unitDirection = Vector3.new(direction.X / magnitude, 0, direction.Y / magnitude)
					local cellWorld = FastFlowHelper.GridCellToWorldXZ(cell, mapping, mapping.OriginWorld.Y)
					local rayOrigin = cellWorld + Vector3.new(0, math.max(4, arrowConfig.RaycastHeight), 0)
					local rayDirection = Vector3.new(0, -math.max(8, arrowConfig.RaycastHeight * 2), 0)
					local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
					local terrainY = if raycastResult ~= nil
						then raycastResult.Position.Y + arrowConfig.TerrainYOffset
						else cellWorld.Y + arrowConfig.TerrainYOffset
					local arrowStart = Vector3.new(cellWorld.X, terrainY, cellWorld.Z)
					local arrowMidpoint = arrowStart + unitDirection * (arrowLength * 0.5)

					local shaft = Instance.new("Part")
					shaft.Name = "FlowArrow"
					shaft.Anchored = true
					shaft.CanCollide = false
					shaft.CanTouch = false
					shaft.CanQuery = false
					shaft.Color = arrowConfig.Color
					shaft.Size = Vector3.new(arrowWidth, arrowWidth, arrowLength)
					shaft.CFrame = CFrame.lookAt(arrowMidpoint, arrowMidpoint + unitDirection)
					shaft.Parent = folder

					renderedArrows += 1
				end
			end
		end
	end
end

-- Registers the enemy actor type so the combat runtime can instantiate enemy behavior trees.
--[=[
    @within EnemyCombatAdapterService
    Registers the enemy actor type with the combat runtime.
    @return Result.Result<boolean> -- Whether the actor type registration succeeded.
]=]
function EnemyCombatAdapterService:RegisterActorType(): Result.Result<boolean>
	return Result.Catch(function()
		AI.ValidateSemanticContract("Enemy", EnemySemanticRequirements, EnemyRuntimeBinding, {
			RuntimeOwner = self._runtimeOwner,
		})

		return self._combatContext:RegisterActorType({
			ActorType = "Enemy",
			Conditions = Nodes.Conditions,
			Commands = Nodes.Commands,
			Executors = Executors,
			SemanticRequirements = EnemySemanticRequirements,
			RuntimeBinding = EnemyRuntimeBinding,
			RuntimeOwner = self._runtimeOwner,
		})
	end, "Enemy:RegisterActorType")
end

-- Registers one enemy entity as a runtime actor and builds its per-tick adapter hooks.
--[=[
    @within EnemyCombatAdapterService
    Registers one enemy entity with the combat runtime.
    @param entity number -- Enemy entity id to register.
    @return Result.Result<string> -- Actor handle for the registered enemy.
]=]
function EnemyCombatAdapterService:RegisterActor(entity: number): Result.Result<string>
	self:_EnsureFastFlowConfigured()

	-- Resolve the enemy identity and behavior profile before the runtime sees the actor.
	local identity = self._entityFactory:GetIdentity(entity)
	local role = self._entityFactory:GetRole(entity)
	local roleName = if role ~= nil and role.Role ~= nil then role.Role else "Swarm"
	local roleConfig = EnemyConfig.Roles[roleName] :: EnemyRoleConfig?
	assert(roleConfig ~= nil, ("EnemyCombatAdapterService: missing config for role '%s'"):format(tostring(roleName)))
	local runtimeProfile = EnemyRuntimeProfiles.GetByVariant(roleConfig.RuntimeProfileId)
	local actorHandle = self:_BuildActorHandle(entity)

	-- Seed the goal position and lock-on state before the actor begins ticking.
	self._goalAssignmentResolver.AssignGoalPosition(entity, actorHandle, roleName)
	self._combatServices.LockOnService:AttachConstraint(entity)
	self._entityFactory:SetBehaviorConfig(entity, {
		TickInterval = runtimeProfile.TickInterval,
	})

	-- Hand the combat runtime a thin adapter that delegates back into the enemy context.
	return self._combatContext:RegisterCombatActor({
		ActorType = "Enemy",
		ActorHandle = actorHandle,
		BehaviorDefinition = runtimeProfile.BehaviorDefinition,
		TickInterval = runtimeProfile.TickInterval,
		Adapter = {
			IsActive = function(): boolean
				return self._entityFactory:IsAlive(entity)
			end,
			GetActorLabel = function(): string?
				return if identity ~= nil then identity.EnemyId else actorHandle
			end,
			BuildFacts = function(currentTime: number): { [string]: any }
				return self:_BuildFacts(entity, currentTime)
			end,
			BuildServices = function(currentTime: number, tickId: number?, frameContext: any?): { [string]: any }
				return self:_BuildServices(entity, currentTime, tickId, frameContext)
			end,
			OnCancel = function()
				self._movementProxyResolver.CreateProxy(entity):StopMovement(0)
			end,
			OnRemoved = function()
				self:_ClearCachedFacts(entity)
				self:_ClearCachedExecutorServices(entity)
				self._movementProxyResolver.CreateProxy(entity):StopMovement(0)
				self._combatServices.LockOnService:DetachConstraint(entity)
			end,
			OnActionStateChanged = function(_actionState: any)
				self._entityFactory:MarkDirty(entity)
			end,
			OnActionResult = function(actionResult: any)
				self:_HandleActionResult(entity, actionResult)
			end,
		},
	})
end

-- Unregisters one enemy actor handle when its entity leaves the runtime.
--[=[
    @within EnemyCombatAdapterService
    Unregisters one enemy actor from the combat runtime.
    @param entity number -- Enemy entity id to unregister.
    @return Result.Result<boolean> -- Whether the actor was removed successfully.
]=]
function EnemyCombatAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	self:_ClearCachedFacts(entity)
	self:_ClearCachedExecutorServices(entity)
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
end

-- Returns the stable combat actor handle for one enemy entity.
--[=[
    @within EnemyCombatAdapterService
    Returns the combat actor handle for one enemy entity.
    @param entity number -- Enemy entity id to resolve.
    @return string -- Stable actor handle used by the combat runtime.
]=]
function EnemyCombatAdapterService:GetActorHandle(entity: number): string
	return self:_BuildActorHandle(entity)
end

-- Stores the context that owns this adapter so callbacks can resolve back into it.
--[=[
    @within EnemyCombatAdapterService
    Stores the runtime owner that owns this adapter service.
    @param runtimeOwner any -- Owning context or runtime object.
]=]
function EnemyCombatAdapterService:ConfigureRuntimeOwner(runtimeOwner: any)
	self._runtimeOwner = runtimeOwner
end

-- ── Private ───────────────────────────────────────────────────────────────────

-- Configures shared combat services once so all enemy actors reuse the same adapters.
function EnemyCombatAdapterService:_ConfigureCombatServices()
	if self._configuredCombatServices then
		return
	end

	-- Install shared enemy target resolution before any combat tick asks for hit validation.
	local hitTargetResolver = EnemyHitTargetResolverFactory.Create({
		BaseInstanceFactory = self._baseInstanceFactory,
		StructureInstanceFactory = self._structureInstanceFactory,
	})

	self._combatServices.HitboxService:RegisterTargetResolver(function(hitPart: BasePart): any?
		return hitTargetResolver.ResolveHitTarget(hitPart)
	end)
	self._combatServices.HitboxService:RegisterWhitelistResolver("Enemy", function(
		_attackerEntity: number,
		_attackerKind: any,
		attackerModel: Model?
	): { Instance }
		local whitelistInstances = {} :: { Instance }

		for _, structureEntity in ipairs(self._structureEntityFactory:QueryTargetableEntities()) do
			local structureModel = self._structureInstanceFactory:GetInstance(structureEntity)
			if structureModel ~= nil and structureModel.Parent ~= nil and structureModel ~= attackerModel then
				table.insert(whitelistInstances, structureModel)
			end
		end

		local baseEntity = self._baseEntityFactory:GetBaseEntity()
		if baseEntity ~= nil and self._baseEntityFactory:IsActive() then
			local baseInstance = self._baseInstanceFactory:GetBaseModel(baseEntity)
				or self._baseInstanceFactory:GetBaseInstance(baseEntity)
			if baseInstance ~= nil and baseInstance.Parent ~= nil and baseInstance ~= attackerModel then
				table.insert(whitelistInstances, baseInstance)
			end
		end

		return whitelistInstances
	end)
	self._combatServices.StatusService:ConfigureEnemyEntityFactory(self._entityFactory)
	self._combatServices.MovementService:ConfigureLockOnService(self._combatServices.LockOnService)
	self._combatServices.MovementService:ConfigureFlowfieldDebugRenderer(function(
		flowfield: any,
		mapping: FastFlowHelper.TFlowGridMapping,
		goalPosition: Vector3
	)
		self:_VisualizeFlowArrows(flowfield, mapping, goalPosition)
	end)
	self._combatServices.MovementService:ConfigureFastFlow(nil, nil)
	self._combatServices.LockOnService:ConfigureFactories(
		self._entityFactory,
		self._instanceFactory,
		self._structureEntityFactory,
		self._structureInstanceFactory,
		self._baseEntityFactory,
		self._baseInstanceFactory
	)
	self._combatServices.CombatHitResolutionService:ConfigureEnemyMeleeResolver(
		EnemyMeleeResolverFactory.Create({
			BaseContext = self._baseContext,
			BaseEntityFactory = self._baseEntityFactory,
			StructureContext = self._structureContext,
			StructureEntityFactory = self._structureEntityFactory,
		})
	)

	self._configuredCombatServices = true
end

-- Builds the stable combat handle, preferring the enemy's configured id when present.
function EnemyCombatAdapterService:_BuildActorHandle(entity: number): string
	local identity = self._entityFactory:GetIdentity(entity)
	if identity ~= nil and type(identity.EnemyId) == "string" then
		return "Enemy:" .. identity.EnemyId
	end
	return "Enemy:" .. tostring(entity)
end

-- Builds the fact snapshot consumed by enemy behavior nodes on each combat tick.
function EnemyCombatAdapterService:_BuildFacts(entity: number, currentTime: number): { [string]: any }
	self:_RefreshCheapFactGroupDirtiness(entity)
	return RuntimeFactCache.Resolve(self._cachedFactsByEntity, entity, currentTime, {
		DefaultCheapFactGroupRefreshIntervalSeconds = FACT_GROUP_CACHE_REFRESH_INTERVAL_SECONDS,
		RefreshIntervalSeconds = FACT_CACHE_REFRESH_INTERVAL_SECONDS,
		CheapFactGroups = self._factsResolver.BuildCheapFactGroups(entity),
		ValidateCachedTarget = function(
			cachedTargetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			},
			cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			return self._factsResolver.ValidateCachedTarget(cachedTargetState, cheapFacts)
		end,
		ReacquireTarget = function(
			cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			return self._factsResolver.ReacquireTarget(cheapFacts)
		end,
		BuildFactSnapshot = function(
			cheapFacts: { [string]: any },
			targetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			}
		): { [string]: any }
			return self._factsResolver.BuildFactSnapshot(cheapFacts, targetState)
		end,
		GetActorPosition = function(cheapFacts: { [string]: any }): Vector3?
			return cheapFacts.ActorPosition
		end,
	})
end

function EnemyCombatAdapterService:_RefreshCheapFactGroupDirtiness(entity: number)
	local cacheRecord = RuntimeFactCache.GetRecord(self._cachedFactsByEntity, entity)
	if cacheRecord == nil then
		return
	end

	local currentPositionRecord = self._entityFactory:GetPosition(entity)
	local currentPosition = if currentPositionRecord ~= nil then currentPositionRecord.CFrame.Position else nil
	local currentRole = self._entityFactory:GetRole(entity)
	local currentAttackRange = if currentRole ~= nil and type(currentRole.AttackRange) == "number"
		then currentRole.AttackRange
		else nil

	local spatialCombatGroup = cacheRecord.CheapFactGroups[CHEAP_FACT_GROUP_SPATIAL_COMBAT]
	if spatialCombatGroup ~= nil then
		local cachedSpatialFacts = spatialCombatGroup.Facts
		if _HasPositionChanged(cachedSpatialFacts.ActorPosition, currentPosition)
			or cachedSpatialFacts.AttackRange ~= currentAttackRange
		then
			RuntimeFactCache.MarkCheapFactGroupDirty(
				self._cachedFactsByEntity,
				entity,
				CHEAP_FACT_GROUP_SPATIAL_COMBAT
			)
		end
	end

	if self._entityFactory:IsDirty(entity) then
		local pathState = self._entityFactory:GetPathState(entity)
		local hasGoalTarget = pathState ~= nil and pathState.GoalPosition ~= nil
		local navigationGroup = cacheRecord.CheapFactGroups[CHEAP_FACT_GROUP_NAVIGATION]
		if navigationGroup ~= nil and navigationGroup.Facts.HasGoalTarget ~= hasGoalTarget then
			RuntimeFactCache.MarkCheapFactGroupDirty(
				self._cachedFactsByEntity,
				entity,
				CHEAP_FACT_GROUP_NAVIGATION
			)
		end

		local health = self._entityFactory:GetHealth(entity)
		local healthPct = _ResolveHealthPct(health)
		local shouldFlee = healthPct < FLEE_THRESHOLD
		local statusGroup = cacheRecord.CheapFactGroups[CHEAP_FACT_GROUP_STATUS]
		if statusGroup ~= nil then
			local cachedStatusFacts = statusGroup.Facts
			if cachedStatusFacts.HealthPct ~= healthPct or cachedStatusFacts.ShouldFlee ~= shouldFlee then
				RuntimeFactCache.MarkCheapFactGroupDirty(self._cachedFactsByEntity, entity, CHEAP_FACT_GROUP_STATUS)
			end
		end
	end
end

function EnemyCombatAdapterService:_ClearCachedFacts(entity: number)
	RuntimeFactCache.Clear(self._cachedFactsByEntity, entity)
end

function EnemyCombatAdapterService:_ClearCachedExecutorServices(entity: number)
	self._cachedExecutorServicesByEntity[entity] = nil
end

function EnemyCombatAdapterService:_GetOrCreateCachedExecutorServices(entity: number): { [string]: any }
	local cachedServices = self._cachedExecutorServicesByEntity[entity]
	if cachedServices ~= nil then
		return cachedServices
	end

	cachedServices = {
		EnemyEntityFactory = self._enemyFactoryProxyResolver.CreateProxy(entity),
		StructureEntityFactory = self._structureEntityFactory,
		BaseEntityFactory = self._baseEntityFactory,
		CombatPerceptionService = self._perceptionResolver.CreateProxy(),
		EnemyContext = self._runtimeOwner,
		StructureContext = self._structureContext,
		BaseContext = self._baseContext,
		CurrentTime = 0,
		TickStartedAt = nil,
		TickBudgetSeconds = nil,
		HitboxService = self._hitboxProxyResolver.CreateProxy(entity),
		MovementService = self._movementProxyResolver.CreateProxy(entity),
		CombatHitResolutionService = self._combatServices.CombatHitResolutionService,
	}
	self._cachedExecutorServicesByEntity[entity] = cachedServices
	return cachedServices
end

-- Builds the service map exposed to enemy behavior executors for the current tick.
function EnemyCombatAdapterService:_BuildServices(
	entity: number,
	currentTime: number,
	tickId: number?,
	frameContext: any?
): { [string]: any }
	local cachedServices = self:_GetOrCreateCachedExecutorServices(entity)
	cachedServices.CurrentTime = currentTime
	cachedServices.TickId = if type(tickId) == "number" then tickId else nil
	cachedServices.TickStartedAt = if type(frameContext) == "table" and type(frameContext.TickStartedAt) == "number"
		then frameContext.TickStartedAt
		else nil
	cachedServices.TickBudgetSeconds =
		if type(frameContext) == "table" and type(frameContext.TickBudgetSeconds) == "number"
			then frameContext.TickBudgetSeconds
			else nil
	cachedServices.EnemyContext = self._runtimeOwner
	return cachedServices
end

-- Refreshes lock-on state after the combat runtime reports an action result.
function EnemyCombatAdapterService:_HandleActionResult(entity: number, _actionResult: any)
	self._combatServices.LockOnService:UpdateAll({ entity })
end

return EnemyCombatAdapterService
