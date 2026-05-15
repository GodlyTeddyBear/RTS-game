--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)
local MovementMath = require(script.Parent.MovementMath)

type TSharedFlowfieldEntry = MovementTypes.TSharedFlowfieldEntry

return function(MovementService: any)
function MovementService:_IsFastFlowDebugEnabled(): boolean
	return CombatMovementConfig.FASTFLOW_VISUALIZATION.Enabled == true
		or CombatMovementConfig.FASTFLOW_ARROW_VISUALIZATION.Enabled == true
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

	local goalKey = MovementMath.FlowGoalKey(goalCell)
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

end
