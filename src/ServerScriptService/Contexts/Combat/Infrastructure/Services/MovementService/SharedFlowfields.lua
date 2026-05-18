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
		local config = CombatMovementConfig.FASTFLOW_SHARED_FIELDS
		if config.UsePrunedGeneration ~= true then
			return nil
		end

		local starts: { Vector3 } = {}
		local maxStarts = math.max(1, math.floor(config.RepresentativeStartCap or 8))
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

		local newEntry, createReason = self:_CreateSharedFlowfield(goalKey, goalCell, goalWorldSample)
		if newEntry == nil then
			return nil, nil, if createReason ~= nil then createReason else "FastFlowGenerateFailed"
		end

		if existingEntry ~= nil then
			newEntry.RefCount = existingEntry.RefCount
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
		self._flowSettledByEntity[entity] = nil
		return goalKey, goalWorldSample, nil
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
