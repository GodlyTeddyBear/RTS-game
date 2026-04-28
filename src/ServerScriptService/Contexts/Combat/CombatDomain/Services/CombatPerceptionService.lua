--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local FLEE_THRESHOLD = 0.2
local RANGE_RAYCAST_PADDING = 0.05

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
function CombatPerceptionService:Init(_registry: any, _name: string) end

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
	return ModelPlus.GetCenterPosition(model)
end

function CombatPerceptionService:_ResolveTargetRaycastData(
	targetKind: TTargetKind,
	targetEntity: number?
): (Instance?, Vector3?)
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
		if modelRef == nil or modelRef.Model == nil or modelRef.Model.Parent == nil then
			return nil, nil
		end

		return modelRef.Model, _resolveModelReferencePoint(modelRef.Model)
	end

	if targetKind == "Enemy" then
		if targetEntity == nil or self._enemyEntityFactory == nil then
			return nil, nil
		end
		if not self._enemyEntityFactory:IsAlive(targetEntity) then
			return nil, nil
		end

		local modelRef = self._enemyEntityFactory:GetModelRef(targetEntity)
		if modelRef == nil or modelRef.Model == nil or modelRef.Model.Parent == nil then
			return nil, nil
		end

		return modelRef.Model, _resolveModelReferencePoint(modelRef.Model)
	end

	return nil, nil
end

function CombatPerceptionService:_FindNearestStructureInRange(enemyPosition: Vector3, attackRange: number): number?
	if self._structureEntityFactory == nil then
		return nil
	end

	return SpatialQuery.FindBestCandidate(
		enemyPosition,
		self._structureEntityFactory:QueryActiveEntities(),
		function(structureEntity: number): Vector3?
			return self._structureEntityFactory:GetPosition(structureEntity)
		end,
		function(structureEntity: number, distance: number): number?
			if not self:IsTargetInRange(enemyPosition, attackRange, "Structure", structureEntity) then
				return nil
			end

			return -distance
		end,
		attackRange
	)
end

function CombatPerceptionService:_FindNearestEnemyInRange(structurePosition: Vector3, attackRange: number): number?
	return SpatialQuery.FindBestCandidate(
		structurePosition,
		self._enemyEntityFactory:QueryAliveEntities(),
		function(enemyEntity: number): Vector3?
			local position = self._enemyEntityFactory:GetPosition(enemyEntity)
			if position == nil then
				return nil
			end

			return position.CFrame.Position
		end,
		function(enemyEntity: number, distance: number): number?
			if not self:IsTargetInRange(structurePosition, attackRange, "Enemy", enemyEntity) then
				return nil
			end

			return -distance
		end,
		attackRange
	)
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
	if direction.Magnitude <= 0 then
		return true
	end

	local visibilityOptions = SpatialQuery.MergeOptions(
		SpatialQuery.Presets.CharactersOnly,
		SpatialQuery.Presets.IncludeInstances({ targetInstance })
	)

	return SpatialQuery.IsWithinRaycastRange(
		position,
		targetReferencePoint,
		attackRange,
		visibilityOptions,
		RANGE_RAYCAST_PADDING
	)
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

	local hasGoalTarget = pathState ~= nil and pathState.GoalPosition ~= nil

	local healthPct = 1
	if health and health.Max > 0 then
		healthPct = math.clamp(health.Current / health.Max, 0, 1)
	end

	local targetStructureEntity = nil :: number?
	if role and position and position.CFrame and type(role.AttackRange) == "number" then
		targetStructureEntity = self:_FindNearestStructureInRange(position.CFrame.Position, role.AttackRange)
	end

	local hasBaseTargetInRange = false
	if
		targetStructureEntity == nil
		and role
		and position
		and position.CFrame
		and type(role.AttackRange) == "number"
	then
		hasBaseTargetInRange = self:IsTargetInRange(position.CFrame.Position, role.AttackRange, "Base", nil)
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
