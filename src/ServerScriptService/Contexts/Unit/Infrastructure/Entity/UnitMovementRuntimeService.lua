--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local FastFlow = require(ServerStorage.Utilities.FastFlow)
local FastFlowHelper = require(ServerStorage.Utilities.FastFlowHelper)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridSpec = WorldTypes.GridSpec
type Tile = WorldTypes.Tile

local UnitMovementRuntimeService = {}
UnitMovementRuntimeService.__index = UnitMovementRuntimeService

local GOAL_POSITION_EPSILON = 0.01

local function _GetGridSubdivisions(): number
	local gridConfig = CombatMovementConfig.FASTFLOW_GRID
	local configured = if gridConfig ~= nil then gridConfig.Subdivisions else nil
	return if type(configured) == "number" then math.max(1, math.floor(configured)) else 1
end

local function _GetGridOriginWorld(spec: GridSpec): Vector3
	local midCol = math.floor((spec.GridCols + 1) * 0.5)
	local midRow = math.floor((spec.GridRows + 1) * 0.5)
	local localX = -spec.GridSize.X * 0.5 + spec.TileSize * 0.5 + (midCol - 1) * spec.TileSize
	local localZ = -spec.GridSize.Z * 0.5 + spec.TileSize * 0.5 + (midRow - 1) * spec.TileSize
	return spec.GridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
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
		if tile.Coord.GridId ~= spec.GridId then
			continue
		end

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

	return walls, mapping
end

function UnitMovementRuntimeService.new()
	local self = setmetatable({}, UnitMovementRuntimeService)
	self._combatContext = nil
	self._entityContext = nil
	self._unitReadService = nil
	self._worldContext = nil
	self._combatServices = nil
	self._isFastFlowConfigured = false
	self._didConfigureCombatServices = false
	return self
end

function UnitMovementRuntimeService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._entityContext = registry:Get("EntityContext")
	self._unitReadService = registry:Get("UnitEntityReadService")
	self._worldContext = registry:Get("WorldContext")
end

function UnitMovementRuntimeService:GetCombatServices(): any?
	if self._combatServices ~= nil then
		return self._combatServices
	end
	if self._combatContext == nil then
		return nil
	end

	local result = self._combatContext:GetCombatRuntimeServices()
	if result.success then
		self._combatServices = result.value
	end
	return self._combatServices
end

function UnitMovementRuntimeService:ConfigureCombatServices()
	if self._didConfigureCombatServices then
		return
	end

	local combatServices = self:GetCombatServices()
	if combatServices == nil then
		return
	end

	if combatServices.MovementService ~= nil and combatServices.LockOnService ~= nil then
		combatServices.MovementService:ConfigureLockOnService(combatServices.LockOnService)
	end
	self._didConfigureCombatServices = true
end

function UnitMovementRuntimeService:WarmFastFlowForRun(): boolean
	local combatServices = self:GetCombatServices()
	if combatServices == nil or combatServices.MovementService == nil then
		return false
	end

	combatServices.MovementService:ResetFastFlowRuntime()
	combatServices.MovementService:ConfigureFastFlow(nil, nil)
	self._isFastFlowConfigured = false
	self:_EnsureFastFlowConfigured()
	return self._isFastFlowConfigured == true
end

function UnitMovementRuntimeService:StartAdvance(entity: number, movementMode: string, goalPosition: Vector3): (boolean, string?)
	self:ConfigureCombatServices()
	self:_EnsureFastFlowConfigured()

	local combatServices = self:GetCombatServices()
	if combatServices == nil or combatServices.MovementService == nil then
		return false, "MissingMovementService"
	end

	return combatServices.MovementService:StartAdvance(self:_BuildMovementBinding(entity), movementMode, goalPosition)
end

function UnitMovementRuntimeService:StepAdvance(entity: number, services: any?): (boolean, string?)
	local combatServices = self:GetCombatServices()
	if combatServices == nil or combatServices.MovementService == nil then
		return false, "MissingMovementService"
	end

	return combatServices.MovementService:StepAdvance(self:_BuildMovementBinding(entity), services)
end

function UnitMovementRuntimeService:StopMovement(entity: number)
	local combatServices = self:GetCombatServices()
	if combatServices == nil or combatServices.MovementService == nil then
		return
	end

	combatServices.MovementService:StopMovement(self:_BuildMovementBinding(entity))
end

function UnitMovementRuntimeService:_EnsureFastFlowConfigured()
	if self._isFastFlowConfigured then
		return
	end

	local combatServices = self:GetCombatServices()
	if combatServices == nil or combatServices.MovementService == nil then
		return
	end

	local pathfinder, mapping = self:_ResolveFastFlowConfiguration()
	if pathfinder == nil or mapping == nil then
		return
	end

	combatServices.MovementService:ConfigureFastFlow(pathfinder, mapping)
	self._isFastFlowConfigured = true
end

function UnitMovementRuntimeService:_ResolveFastFlowConfiguration(): (any?, FastFlowHelper.TFlowGridMapping?)
	if self._worldContext == nil then
		return nil, nil
	end

	local gridSpecsResult = self._worldContext:GetGridSpecList()
	local tilesResult = self._worldContext:GetAllTilesView()
	if not gridSpecsResult.success or not tilesResult.success then
		return nil, nil
	end

	local selectedGrid = gridSpecsResult.value[1]
	if selectedGrid == nil then
		return nil, nil
	end

	local walls, mapping = _BuildWallsFromTiles(selectedGrid, tilesResult.value)
	return FastFlowHelper.CreatePathfinderFromWalls(walls), mapping
end

function UnitMovementRuntimeService:_BuildMovementBinding(entity: number): any
	return {
		ActorKey = "Unit:" .. tostring(entity),
		EntityId = entity,
		GetPathState = function()
			return self._unitReadService:GetPathState(entity)
		end,
		SetPathMoving = function(_binding: any, isMoving: boolean)
			self._entityContext:Set(entity, "PathState", self:_BuildPathMovingState(entity, isMoving), "Unit")
			self._entityContext:Add(entity, "DirtyTag", "Entity")
		end,
		GetModelRef = function()
			local modelRef = self._unitReadService:GetModelRef(entity)
			if type(modelRef) == "table" and modelRef.Model ~= nil then
				return modelRef
			end

			local boundResult = self._entityContext:GetBoundInstance(entity)
			local boundInstance = if boundResult.success then boundResult.value else nil
			return if boundInstance ~= nil and boundInstance:IsA("Model") then { Model = boundInstance } else nil
		end,
		GetCurrentMoveSpeed = function()
			return self._unitReadService:GetCurrentMoveSpeed(entity)
		end,
		GetAgentParams = function()
			local identity = self._unitReadService:GetIdentity(entity)
			local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
			local roleName = if definition ~= nil then definition.Role else nil
			local config = if roleName ~= nil then CombatMovementConfig.AGENT_PARAMS_BY_UNIT_ROLE[roleName] else nil
			return if config ~= nil then config else CombatMovementConfig.DEFAULT_AGENT_PARAMS
		end,
		CountFlowEligiblePeers = function(_binding: any, goalPosition: Vector3): number
			local groupSize = 0
			for _, candidateEntity in ipairs(self._unitReadService:QueryActiveEntities()) do
				local pathState = self._unitReadService:GetPathState(candidateEntity)
				local candidateGoal = if type(pathState) == "table" then pathState.GoalPosition else nil
				if candidateGoal == nil or (candidateGoal - goalPosition).Magnitude > GOAL_POSITION_EPSILON then
					continue
				end

				local identity = self._unitReadService:GetIdentity(candidateEntity)
				local definition = if type(identity) == "table" then UnitConfig.Definitions[identity.UnitId] else nil
				if definition ~= nil and (definition.MovementMode == "Any" or definition.MovementMode == "Boids") then
					groupSize += 1
				end
			end
			return groupSize
		end,
	}
end

function UnitMovementRuntimeService:_BuildPathMovingState(entity: number, isMoving: boolean): any
	local state = self._unitReadService:GetPathState(entity) or {}
	return {
		GoalPosition = state.GoalPosition,
		RequestedGoalPosition = state.RequestedGoalPosition,
		GoalRevision = state.GoalRevision or 0,
		FailedGoalRevision = state.FailedGoalRevision,
		IsMoving = isMoving,
	}
end

return UnitMovementRuntimeService
