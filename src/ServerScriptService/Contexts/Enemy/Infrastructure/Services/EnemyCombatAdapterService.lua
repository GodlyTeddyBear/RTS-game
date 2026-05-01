--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local HitboxConfig = require(ReplicatedStorage.Contexts.Combat.Config.HitboxConfig)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)
local SwarmBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.SwarmBehavior)
local TankBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.TankBehavior)

local FLEE_THRESHOLD = 0.2

local EnemyBehaviorDefinitions = table.freeze({
	Swarm = SwarmBehavior,
	Tank = TankBehavior,
})

local EnemySemanticRequirements = table.freeze({
	FactsDependOnPolling = true,
	AttributesDependOnProjection = true,
})

local EnemyRuntimeBinding = table.freeze({
	ServiceField = "_syncService",
	PollPhase = "EnemySync",
	SyncPhase = "EnemySync",
})

local EnemyCombatAdapterService = {}
EnemyCombatAdapterService.__index = EnemyCombatAdapterService

function EnemyCombatAdapterService.new()
	local self = setmetatable({}, EnemyCombatAdapterService)
	self._configuredCombatServices = false
	self._runtimeOwner = nil
	return self
end

function EnemyCombatAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
	self._instanceFactory = registry:Get("EnemyInstanceFactory")
end

function EnemyCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._structureContext = registry:Get("StructureContext")
	self._baseContext = registry:Get("BaseContext")
	self._structureEntityFactory = self._structureContext:GetEntityFactory().value
	self._baseEntityFactory = self._baseContext:GetEntityFactory().value
	self._combatServices = self._combatContext:GetCombatRuntimeServices().value
	self:_ConfigureCombatServices()
end

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

function EnemyCombatAdapterService:RegisterActor(entity: number): Result.Result<string>
	local identity = self._entityFactory:GetIdentity(entity)
	local role = self._entityFactory:GetRole(entity)
	local roleName = if role ~= nil and role.Role ~= nil then role.Role else "Swarm"
	local behaviorDefinition = EnemyBehaviorDefinitions[roleName] or SwarmBehavior
	local defaults = BehaviorConfig.DEFAULTS_BY_ROLE[roleName] or BehaviorConfig.DEFAULT
	local actorHandle = self:_BuildActorHandle(entity)
	self:_AssignGoalPosition(entity, actorHandle, roleName)
	self._combatServices.LockOnService:AttachConstraint(entity)

	return self._combatContext:RegisterCombatActor({
		ActorType = "Enemy",
		ActorHandle = actorHandle,
		BehaviorDefinition = behaviorDefinition,
		TickInterval = defaults.TickInterval,
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
			BuildServices = function(currentTime: number): { [string]: any }
				return self:_BuildServices(entity, currentTime)
			end,
			OnCancel = function()
				self._combatServices.MovementService:StopMovement(entity)
			end,
			OnRemoved = function()
				self._combatServices.MovementService:StopMovement(entity)
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

function EnemyCombatAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
end

function EnemyCombatAdapterService:GetActorHandle(entity: number): string
	return self:_BuildActorHandle(entity)
end

function EnemyCombatAdapterService:ConfigureRuntimeOwner(runtimeOwner: any)
	self._runtimeOwner = runtimeOwner
end

function EnemyCombatAdapterService:_ConfigureCombatServices()
	if self._configuredCombatServices then
		return
	end

	self._combatServices.HitboxService:RegisterTargetResolver(function(hitPart: BasePart): any?
		return self:_ResolveHitEntity(hitPart)
	end)
	self._combatServices.MovementService:ConfigureEnemyEntityFactory(self._entityFactory)
	self._combatServices.LockOnService:ConfigureFactories(
		self._entityFactory,
		self._structureEntityFactory,
		self._baseEntityFactory
	)
	self._combatServices.CombatHitResolutionService:ConfigureEnemyMeleeResolver({
		IsBaseActive = function(): boolean
			return self._baseEntityFactory:IsActive()
		end,
		IsStructureActive = function(structureEntity: number): boolean
			return self._structureEntityFactory:IsActive(structureEntity)
		end,
		ApplyBaseDamage = function(damage: number): Result.Result<boolean>
			return self._baseContext:ApplyDamage(damage)
		end,
		ApplyStructureDamage = function(structureEntity: number, damage: number): Result.Result<boolean>
			return self._structureContext:ApplyDamage(structureEntity, damage)
		end,
	})

	self._configuredCombatServices = true
end

function EnemyCombatAdapterService:_BuildActorHandle(entity: number): string
	local identity = self._entityFactory:GetIdentity(entity)
	if identity ~= nil and type(identity.EnemyId) == "string" then
		return "Enemy:" .. identity.EnemyId
	end
	return "Enemy:" .. tostring(entity)
end

function EnemyCombatAdapterService:_AssignGoalPosition(entity: number, actorHandle: string, roleName: string)
	local baseTargetResult = self._baseContext:GetBaseTargetCFrame()
	if not baseTargetResult.success or baseTargetResult.value == nil then
		Result.MentionError("Enemy:RegisterActor", "Enemy goal position could not be assigned", {
			ActorHandle = actorHandle,
			Role = roleName,
			GoalPositionAssigned = false,
			CauseType = if not baseTargetResult.success then baseTargetResult.type else "MissingBaseTargetCFrame",
			CauseMessage = if not baseTargetResult.success
				then baseTargetResult.message
				else "Base target CFrame was nil during enemy registration",
		}, if not baseTargetResult.success then baseTargetResult.type else "MissingBaseTargetCFrame")
		return
	end

	self._entityFactory:SetGoalPosition(entity, baseTargetResult.value.Position)
end

function EnemyCombatAdapterService:_BuildFacts(entity: number, _currentTime: number): { [string]: any }
	local pathState = self._entityFactory:GetPathState(entity)
	local health = self._entityFactory:GetHealth(entity)
	local role = self._entityFactory:GetRole(entity)
	local position = self._entityFactory:GetPosition(entity)

	local healthPct = 1
	if health ~= nil and health.Max > 0 then
		healthPct = math.clamp(health.Current / health.Max, 0, 1)
	end

	local targetStructureEntity = nil :: number?
	if role ~= nil and position ~= nil and type(role.AttackRange) == "number" then
		targetStructureEntity = self:_FindNearestStructureInRange(position.CFrame.Position, role.AttackRange)
	end

	local hasBaseTargetInRange = false
	if targetStructureEntity == nil and role ~= nil and position ~= nil and type(role.AttackRange) == "number" then
		hasBaseTargetInRange = self:_IsTargetInRange(position.CFrame.Position, role.AttackRange, "Base", nil)
	end

	return {
		HasGoalTarget = pathState ~= nil and pathState.GoalPosition ~= nil,
		HealthPct = healthPct,
		ShouldFlee = healthPct < FLEE_THRESHOLD,
		TargetStructureEntity = targetStructureEntity,
		HasBaseTargetInRange = hasBaseTargetInRange,
	}
end

function EnemyCombatAdapterService:_BuildServices(entity: number, currentTime: number): { [string]: any }
	local enemyFactoryProxy = self:_BuildEnemyFactoryProxy(entity)
	return {
		EnemyEntityFactory = enemyFactoryProxy,
		StructureEntityFactory = self._structureEntityFactory,
		BaseEntityFactory = self._baseEntityFactory,
		CombatPerceptionService = self:_BuildPerceptionProxy(),
		EnemyContext = nil,
		StructureContext = self._structureContext,
		BaseContext = self._baseContext,
		CurrentTime = currentTime,
		HitboxService = self:_BuildHitboxProxy(entity),
		MovementService = self:_BuildMovementProxy(entity),
		CombatHitResolutionService = self._combatServices.CombatHitResolutionService,
	}
end

function EnemyCombatAdapterService:_BuildMovementProxy(entity: number): any
	local movementService = self._combatServices.MovementService
	return {
		StartAdvance = function(_proxy: any, _runtimeId: number, movementMode: any): (boolean, string?)
			return movementService:StartAdvance(entity, movementMode)
		end,
		TickAdvance = function(_proxy: any, _runtimeId: number): ("Running" | "Success" | "Fail", string?)
			return movementService:TickAdvance(entity)
		end,
		StopMovement = function(_proxy: any, _runtimeId: number)
			movementService:StopMovement(entity)
		end,
	}
end

function EnemyCombatAdapterService:_BuildEnemyFactoryProxy(entity: number): any
	local factory = self._entityFactory
	return {
		ResolveRuntimeEntity = function(_proxy: any, _runtimeId: number): number
			return entity
		end,
		GetPathState = function(_proxy: any, _runtimeId: number)
			return factory:GetPathState(entity)
		end,
		GetRole = function(_proxy: any, _runtimeId: number)
			return factory:GetRole(entity)
		end,
		GetModelRef = function(_proxy: any, _runtimeId: number)
			return factory:GetModelRef(entity)
		end,
		GetPosition = function(_proxy: any, _runtimeId: number)
			return factory:GetPosition(entity)
		end,
		GetAttackCooldown = function(_proxy: any, _runtimeId: number)
			return factory:GetAttackCooldown(entity)
		end,
		SetTarget = function(
			_proxy: any,
			_runtimeId: number,
			targetEntity: number?,
			targetKind: "Structure" | "Enemy" | "Base"
		)
			factory:SetTarget(entity, targetEntity, targetKind)
		end,
		ClearTarget = function(_proxy: any, _runtimeId: number)
			factory:ClearTarget(entity)
		end,
		SetLastAttackTime = function(_proxy: any, _runtimeId: number, lastAttackTime: number)
			factory:SetLastAttackTime(entity, lastAttackTime)
		end,
		PromoteToCommitted = function(_proxy: any, _runtimeId: number)
			factory:PromoteToCommitted(entity)
		end,
	}
end

function EnemyCombatAdapterService:_BuildHitboxProxy(entity: number): any
	local hitboxService = self._combatServices.HitboxService
	return {
		CreateAttackHitbox = function(_proxy: any, _runtimeId: number, attackerKind: any, config: any)
			local modelRef = self._entityFactory:GetModelRef(entity)
			local model = if modelRef ~= nil then modelRef.Model else nil
			return hitboxService:CreateAttackHitboxForModel(
				entity,
				attackerKind,
				model,
				config or HitboxConfig.AttackStructure
			)
		end,
		DestroyHitbox = function(_proxy: any, handle: string)
			hitboxService:DestroyHitbox(handle)
		end,
		GetHitEntities = function(_proxy: any, handle: string)
			return hitboxService:GetHitEntities(handle)
		end,
	}
end

function EnemyCombatAdapterService:_BuildPerceptionProxy(): any
	return {
		IsTargetInRange = function(
			_proxy: any,
			position: Vector3,
			attackRange: number,
			targetKind: any,
			targetEntity: number?
		)
			return self:_IsTargetInRange(position, attackRange, targetKind, targetEntity)
		end,
	}
end

function EnemyCombatAdapterService:_FindNearestStructureInRange(position: Vector3, attackRange: number): number?
	return SpatialQuery.FindBestCandidate(
		position,
		self._structureEntityFactory:QueryActiveEntities(),
		function(structureEntity: number): Vector3?
			return self._structureEntityFactory:GetPosition(structureEntity)
		end,
		function(structureEntity: number, distance: number): number?
			if not self:_IsTargetInRange(position, attackRange, "Structure", structureEntity) then
				return nil
			end
			return -distance
		end,
		attackRange
	)
end

function EnemyCombatAdapterService:_IsTargetInRange(
	position: Vector3,
	attackRange: number,
	targetKind: "Base" | "Structure" | "Enemy",
	targetEntity: number?
): boolean
	local targetInstance, targetPosition = self:_ResolveTargetRaycastData(targetKind, targetEntity)
	if targetInstance == nil or targetPosition == nil then
		return false
	end

	if targetKind == "Base" then
		local overlappingParts = SpatialQuery.OverlapRadius(
			position,
			attackRange,
			SpatialQuery.Presets.IncludeInstances({ targetInstance })
		)
		if #overlappingParts > 0 then
			return true
		end
	end

	return SpatialQuery.IsWithinRaycastRange(
		position,
		targetPosition,
		attackRange,
		SpatialQuery.MergeOptions(
			SpatialQuery.Presets.CharactersOnly,
			SpatialQuery.Presets.IncludeInstances({ targetInstance })
		),
		0.05
	)
end

function EnemyCombatAdapterService:_ResolveTargetRaycastData(
	targetKind: "Base" | "Structure" | "Enemy",
	targetEntity: number?
): (Instance?, Vector3?)
	if targetKind == "Base" then
		if not self._baseEntityFactory:IsActive() then
			return nil, nil
		end

		local baseRef = self._baseEntityFactory:GetInstanceRef()
		if baseRef == nil or baseRef.Instance == nil then
			return nil, nil
		end

		if baseRef.Instance:IsA("Model") then
			return baseRef.Instance, ModelPlus.GetCenterPosition(baseRef.Instance)
		end

		if baseRef.Instance:IsA("BasePart") then
			return baseRef.Instance, baseRef.Instance.Position
		end

		if baseRef.Anchor ~= nil then
			return baseRef.Instance, baseRef.Anchor.Position
		end

		return nil, nil
	end

	if targetKind == "Structure" then
		if targetEntity == nil or not self._structureEntityFactory:IsActive(targetEntity) then
			return nil, nil
		end

		local modelRef = self._structureEntityFactory:GetModelRef(targetEntity)
		if modelRef == nil or modelRef.Model == nil or modelRef.Model.Parent == nil then
			return nil, nil
		end
		return modelRef.Model, ModelPlus.GetCenterPosition(modelRef.Model)
	end

	return nil, nil
end

function EnemyCombatAdapterService:_ResolveHitEntity(hitPart: BasePart): any?
	if self._baseEntityFactory:IsPartOfBase(hitPart) then
		return {
			Kind = "Base",
			Entity = 0,
		}
	end

	local model = hitPart:FindFirstAncestorOfClass("Model")
	if model == nil then
		return nil
	end

	local structureEntity = self._structureEntityFactory:GetEntityByModel(model)
	if structureEntity ~= nil then
		return {
			Kind = "Structure",
			Entity = structureEntity,
		}
	end

	return nil
end

function EnemyCombatAdapterService:_HandleActionResult(entity: number, _actionResult: any)
	self._combatServices.LockOnService:UpdateAll({ entity })
end

return EnemyCombatAdapterService
