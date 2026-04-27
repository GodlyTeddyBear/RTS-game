--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local FLEE_THRESHOLD = 0.2
local RANGE_RAYCAST_PADDING = 0.05
local RAYCAST_LOG_THROTTLE_SECONDS = 1
local _lastRaycastLogAt = 0

--[=[
	@class CombatPerceptionService
	Builds the facts snapshot passed into combat behavior trees.
	@server
]=]
local CombatPerceptionService = {}
CombatPerceptionService.__index = CombatPerceptionService

--[=[
	@within CombatPerceptionService
	Creates a new combat perception service.
	@return CombatPerceptionService -- Service instance used to build behavior facts.
]=]
function CombatPerceptionService.new()
	return setmetatable({}, CombatPerceptionService)
end

--[=[
	@within CombatPerceptionService
	Resolves the enemy entity factory used to inspect path and health state.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatPerceptionService:Init(_registry: any, _name: string)
end

--[=[
	@within CombatPerceptionService
	Stores the enemy entity factory needed to build perception snapshots.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the service.
]=]
function CombatPerceptionService:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
	self._baseEntityFactory = registry:Get("BaseEntityFactory")
end

type TTargetKind = "Base" | "Structure" | "Enemy"

local function _resolveModelReferencePoint(model: Model): Vector3
	local boundsCFrame, _ = model:GetBoundingBox()
	return boundsCFrame.Position
end

function CombatPerceptionService:_ResolveTargetRaycastData(targetKind: TTargetKind, targetEntity: number?): (Instance?, Vector3?)
	if targetKind == "Base" then
		if self._baseEntityFactory == nil or not self._baseEntityFactory:IsActive() then
			return nil, nil
		end

		local baseRef = self._baseEntityFactory:GetInstanceRef()
		if baseRef == nil then
			return nil, nil
		end

		if baseRef.Instance:IsA("Model") then
			return baseRef.Instance, _resolveModelReferencePoint(baseRef.Instance)
		end
		if baseRef.Instance:IsA("BasePart") then
			return baseRef.Instance, baseRef.Instance.Position
		end

		return baseRef.Instance, baseRef.Anchor.Position
	end

	if targetKind == "Structure" then
		if targetEntity == nil or self._structureEntityFactory == nil then
			return nil, nil
		end
		if not self._structureEntityFactory:IsActive(targetEntity) then
			return nil, nil
		end

		local modelRef = self._structureEntityFactory:GetModelRef(targetEntity)
		if modelRef == nil or modelRef.model == nil or modelRef.model.Parent == nil then
			return nil, nil
		end

		return modelRef.model, _resolveModelReferencePoint(modelRef.model)
	end

	if targetKind == "Enemy" then
		if targetEntity == nil or self._enemyEntityFactory == nil then
			return nil, nil
		end
		if not self._enemyEntityFactory:IsAlive(targetEntity) then
			return nil, nil
		end

		local modelRef = self._enemyEntityFactory:GetModelRef(targetEntity)
		if modelRef == nil or modelRef.model == nil or modelRef.model.Parent == nil then
			return nil, nil
		end

		return modelRef.model, _resolveModelReferencePoint(modelRef.model)
	end

	return nil, nil
end

function CombatPerceptionService:_FindNearestStructureInRange(enemyPosition: Vector3, attackRange: number): number?
	if self._structureEntityFactory == nil then
		return nil
	end

	local nearestStructure = nil :: number?
	local nearestDistanceSq = math.huge
	local maxDistanceSq = attackRange * attackRange

	for _, structureEntity in ipairs(self._structureEntityFactory:QueryActiveEntities()) do
		local structurePosition = self._structureEntityFactory:GetPosition(structureEntity)
		if structurePosition == nil then
			continue
		end

		local offset = structurePosition - enemyPosition
		local distanceSq = offset:Dot(offset)
		if distanceSq <= maxDistanceSq and distanceSq < nearestDistanceSq then
			if self:IsTargetInRange(enemyPosition, attackRange, "Structure", structureEntity) then
				nearestDistanceSq = distanceSq
				nearestStructure = structureEntity
			end
		end
	end

	return nearestStructure
end

function CombatPerceptionService:_FindNearestEnemyInRange(structurePosition: Vector3, attackRange: number): number?
	local nearestEnemy = nil :: number?
	local nearestDistanceSq = math.huge
	local maxDistanceSq = attackRange * attackRange

	for _, enemyEntity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
		local position = self._enemyEntityFactory:GetPosition(enemyEntity)
		if position == nil then
			continue
		end

		local offset = position.cframe.Position - structurePosition
		local distanceSq = offset:Dot(offset)
		if distanceSq <= maxDistanceSq and distanceSq < nearestDistanceSq then
			if self:IsTargetInRange(structurePosition, attackRange, "Enemy", enemyEntity) then
				nearestDistanceSq = distanceSq
				nearestEnemy = enemyEntity
			end
		end
	end

	return nearestEnemy
end

function CombatPerceptionService:IsTargetInRangeByRaycast(
	position: Vector3,
	targetInstance: Instance?,
	targetReferencePoint: Vector3?,
	attackRange: number
): boolean
	if targetInstance == nil or targetReferencePoint == nil then
		return false
	end

	if type(attackRange) ~= "number" or attackRange <= 0 then
		return false
	end

	local direction = targetReferencePoint - position
	local directionMagnitude = direction.Magnitude
	if directionMagnitude <= 0 then
		return true
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { targetInstance }
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = false

	local raycastResult = Workspace:Raycast(
		position,
		direction.Unit * (directionMagnitude + RANGE_RAYCAST_PADDING),
		raycastParams
	)
	if raycastResult == nil then
		local now = os.clock()
		if now - _lastRaycastLogAt >= RAYCAST_LOG_THROTTLE_SECONDS then
			_lastRaycastLogAt = now
			Result.MentionError("CombatPerceptionService:IsTargetInRangeByRaycast", "Failed raycast against target instance", {
				PositionX = position.X,
				PositionY = position.Y,
				PositionZ = position.Z,
				ReferenceX = targetReferencePoint.X,
				ReferenceY = targetReferencePoint.Y,
				ReferenceZ = targetReferencePoint.Z,
				AttackRange = attackRange,
				TargetName = targetInstance.Name,
				TargetClass = targetInstance.ClassName,
			}, "TargetRangeRaycastMiss")
		end
		return false
	end

	local hitDistance = (raycastResult.Position - position).Magnitude
	return hitDistance <= attackRange
end

function CombatPerceptionService:IsTargetInRange(
	position: Vector3,
	attackRange: number,
	targetKind: TTargetKind,
	targetEntity: number?
): boolean
	local targetInstance, targetReferencePoint = self:_ResolveTargetRaycastData(targetKind, targetEntity)
	return self:IsTargetInRangeByRaycast(position, targetInstance, targetReferencePoint, attackRange)
end

--[=[
	@within CombatPerceptionService
	Returns the perception facts a behavior tree needs to decide the next action.
	@param entity number -- Enemy entity id whose state should be sampled.
	@param _currentTime number -- Current timestamp, reserved for future time-based facts.
	@return table -- Facts snapshot consumed by combat behavior trees.
]=]
function CombatPerceptionService:BuildSnapshot(entity: number, _currentTime: number)
	local pathState = self._enemyEntityFactory:GetPathState(entity)
	local health = self._enemyEntityFactory:GetHealth(entity)
	local role = self._enemyEntityFactory:GetRole(entity)
	local position = self._enemyEntityFactory:GetPosition(entity)

	local hasGoalTarget = pathState ~= nil and pathState.goalPosition ~= nil

	local healthPct = 1
	if health and health.max > 0 then
		healthPct = math.clamp(health.current / health.max, 0, 1)
	end

	local targetStructureEntity = nil :: number?
	if role and position and position.cframe and type(role.attackRange) == "number" then
		targetStructureEntity = self:_FindNearestStructureInRange(position.cframe.Position, role.attackRange)
	end

	local hasBaseTargetInRange = false
	if targetStructureEntity == nil and role and position and position.cframe and type(role.attackRange) == "number" then
		hasBaseTargetInRange = self:IsTargetInRange(position.cframe.Position, role.attackRange, "Base", nil)
	end

	return {
		HasGoalTarget = hasGoalTarget,
		HealthPct = healthPct,
		ShouldFlee = healthPct < FLEE_THRESHOLD,
		TargetStructureEntity = targetStructureEntity,
		HasBaseTargetInRange = hasBaseTargetInRange,
	}
end

function CombatPerceptionService:BuildStructureSnapshot(entity: number, _currentTime: number)
	local attackStats = self._structureEntityFactory:GetAttackStats(entity)
	local position = self._structureEntityFactory:GetPosition(entity)

	local targetEnemyEntity = nil :: number?
	if attackStats ~= nil and position ~= nil then
		targetEnemyEntity = self:_FindNearestEnemyInRange(position, attackStats.AttackRange)
	end

	return {
		TargetEnemyEntity = targetEnemyEntity,
	}
end

return CombatPerceptionService
