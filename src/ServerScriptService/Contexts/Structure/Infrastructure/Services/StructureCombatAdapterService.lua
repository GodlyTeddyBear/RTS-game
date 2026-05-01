--!strict

--[=[
    @class StructureCombatAdapterService
    Bridges structure entities into the combat runtime and wires structure attacks to enemy targeting and damage.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local StructureAttackExecutor = require(script.Parent.Parent.BehaviorSystem.Executors.StructureAttackExecutor)
local StructureBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.StructureBehavior)

local StructureCombatAdapterService = {}
StructureCombatAdapterService.__index = StructureCombatAdapterService

local StructureSemanticRequirements = table.freeze({
	FactsDependOnPolling = false,
	AttributesDependOnProjection = true,
})

local StructureRuntimeBinding = table.freeze({
	ServiceField = "_gameObjectSyncService",
	SyncPhase = "StructureSync",
})

local function _CloneActionState(actionState: any): any
	if type(actionState) ~= "table" then
		return {
			CurrentActionId = nil,
			ActionState = "Idle",
			ActionData = nil,
			PendingActionId = nil,
			PendingActionData = nil,
			StartedAt = nil,
			FinishedAt = nil,
		}
	end

	return {
		CurrentActionId = actionState.CurrentActionId,
		ActionState = actionState.ActionState or "Idle",
		ActionData = actionState.ActionData,
		PendingActionId = actionState.PendingActionId,
		PendingActionData = actionState.PendingActionData,
		StartedAt = actionState.StartedAt,
		FinishedAt = actionState.FinishedAt,
	}
end

-- ── Public ────────────────────────────────────────────────────────────────────

-- Creates a new structure combat adapter service with deferred combat-service wiring.
--[=[
    @within StructureCombatAdapterService
    Creates a new structure combat adapter service.
    @return StructureCombatAdapterService -- Service instance used to register structure combat actors.
]=]
function StructureCombatAdapterService.new()
	local self = setmetatable({}, StructureCombatAdapterService)
	self._configuredCombatServices = false
	self._runtimeOwner = nil
	return self
end

-- Resolves the structure entity factory used to build actor adapters.
--[=[
    @within StructureCombatAdapterService
    Resolves the structure context dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function StructureCombatAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("StructureEntityFactory")
end

-- Caches combat and enemy dependencies before the first structure actor is registered.
--[=[
    @within StructureCombatAdapterService
    Resolves the combat and enemy dependencies used by the adapter service.
    @param registry any -- Registry instance supplied by the context bootstrap.
    @param _name string -- Registry key used to register the service.
]=]
function StructureCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._enemyContext = registry:Get("EnemyContext")
	self._enemyEntityFactory = self._enemyContext:GetEntityFactory().value
	self._enemyInstanceFactory = self._enemyContext:GetInstanceFactory().value
	self._combatServices = self._combatContext:GetCombatRuntimeServices().value
	self:_ConfigureCombatServices()
end

-- Registers the structure actor type so the combat runtime can instantiate structure behavior trees.
--[=[
    @within StructureCombatAdapterService
    Registers the structure actor type with the combat runtime.
    @return Result.Result<boolean> -- Whether the actor type registration succeeded.
]=]
function StructureCombatAdapterService:RegisterActorType(): Result.Result<boolean>
	return Result.Catch(function()
		AI.ValidateSemanticContract("Structure", StructureSemanticRequirements, StructureRuntimeBinding, {
			RuntimeOwner = self._runtimeOwner,
		})

		return self._combatContext:RegisterActorType({
			ActorType = "Structure",
			Conditions = Nodes.Conditions,
			Commands = Nodes.Commands,
			Executors = {
				["Structure.Attack"] = table.freeze({
					ActionId = "Structure.Attack",
					CreateExecutor = StructureAttackExecutor.new,
				}),
			},
			SemanticRequirements = StructureSemanticRequirements,
			RuntimeBinding = StructureRuntimeBinding,
			RuntimeOwner = self._runtimeOwner,
		})
	end, "Structure:RegisterActorType")
end

-- Registers one structure entity as a runtime actor and builds its per-tick adapter hooks.
--[=[
    @within StructureCombatAdapterService
    Registers one structure entity with the combat runtime.
    @param entity number -- Structure entity id to register.
    @return Result.Result<string> -- Actor handle for the registered structure.
]=]
function StructureCombatAdapterService:RegisterActor(entity: number): Result.Result<string>
	return self._combatContext:RegisterCombatActor({
		ActorType = "Structure",
		ActorHandle = self:_BuildActorHandle(entity),
		BehaviorDefinition = StructureBehavior,
		TickInterval = BehaviorConfig.DEFAULT.TickInterval,
		Adapter = {
			IsActive = function(): boolean
				return self._entityFactory:IsActive(entity)
			end,
			GetActorLabel = function(): string?
				return self:_BuildActorHandle(entity)
			end,
			BuildFacts = function(_currentTime: number): { [string]: any }
				return self:_BuildFacts(entity)
			end,
			BuildServices = function(currentTime: number): { [string]: any }
				return self:_BuildServices(entity, currentTime)
			end,
			OnActionStateChanged = function(actionState: any)
				self._entityFactory:SetCombatAction(entity, _CloneActionState(actionState))
			end,
		},
	})
end

-- Unregisters one structure actor when its entity leaves the runtime.
--[=[
    @within StructureCombatAdapterService
    Unregisters one structure actor from the combat runtime.
    @param entity number -- Structure entity id to unregister.
    @return Result.Result<boolean> -- Whether the actor was removed successfully.
]=]
function StructureCombatAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
end

-- Returns the stable combat actor handle for one structure entity.
--[=[
    @within StructureCombatAdapterService
    Returns the combat actor handle for one structure entity.
    @param entity number -- Structure entity id to resolve.
    @return string -- Stable actor handle used by the combat runtime.
]=]
function StructureCombatAdapterService:GetActorHandle(entity: number): string
	return self:_BuildActorHandle(entity)
end

-- Stores the context that owns this adapter so callbacks can resolve back into it.
--[=[
    @within StructureCombatAdapterService
    Stores the runtime owner that owns this adapter service.
    @param runtimeOwner any -- Owning context or runtime object.
]=]
function StructureCombatAdapterService:ConfigureRuntimeOwner(runtimeOwner: any)
	self._runtimeOwner = runtimeOwner
end

-- ── Private ───────────────────────────────────────────────────────────────────

-- Configures shared combat services once so all structure actors reuse the same adapters.
function StructureCombatAdapterService:_ConfigureCombatServices()
	if self._configuredCombatServices then
		return
	end

	-- Install shared hit validation before any structure actor asks for melee or projectile checks.
	self._combatServices.HitboxService:RegisterTargetResolver(function(hitPart: BasePart): any?
		return self:_ResolveHitEntity(hitPart)
	end)

	-- Wire the projectile resolver to enemy and structure contexts so attacks can resolve live targets.
	self._combatServices.ProjectileService:ConfigureStructureBulletResolver({
		ResolveStructureModel = function(structureEntity: number): Model?
			local modelRef = self._entityFactory:GetModelRef(structureEntity)
			return if modelRef ~= nil then modelRef.Model else nil
		end,
		ResolveEnemyCFrame = function(enemyEntity: number): CFrame?
			return self._enemyEntityFactory:GetEntityCFrame(enemyEntity)
		end,
		ResolveEnemyEntity = function(hitPart: Instance): number?
			local model = hitPart:FindFirstAncestorOfClass("Model")
			if model == nil then
				return nil
			end
			return self._enemyInstanceFactory:GetEntity(model)
		end,
		IsEnemyAlive = function(enemyEntity: number): boolean
			return self._enemyEntityFactory:IsAlive(enemyEntity)
		end,
		ApplyEnemyDamage = function(enemyEntity: number, damage: number)
			self._enemyContext:ApplyDamage(enemyEntity, damage)
		end,
	})

	self._configuredCombatServices = true
end

-- Builds the stable combat handle, preferring the structure's configured id when present.
function StructureCombatAdapterService:_BuildActorHandle(entity: number): string
	local identity = self._entityFactory:GetIdentity(entity)
	if identity ~= nil and type(identity.StructureId) == "string" then
		return "Structure:" .. identity.StructureId
	end
	return "Structure:" .. tostring(entity)
end

-- Builds the fact snapshot consumed by structure behavior nodes on each combat tick.
function StructureCombatAdapterService:_BuildFacts(entity: number): { [string]: any }
	-- Read attack state once so target selection is based on a single entity snapshot.
	local attackStats = self._entityFactory:GetAttackStats(entity)
	local position = self._entityFactory:GetPosition(entity)
	local targetEnemyEntity = nil :: number?
	if attackStats ~= nil and position ~= nil then
		targetEnemyEntity = self:_FindNearestEnemyInRange(position, attackStats.AttackRange)
	end

	return {
		TargetEnemyEntity = targetEnemyEntity,
	}
end

-- Builds the service map exposed to structure behavior executors for the current tick.
function StructureCombatAdapterService:_BuildServices(entity: number, currentTime: number): { [string]: any }
	return {
		StructureEntityFactory = self:_BuildStructureFactoryProxy(entity),
		EnemyEntityFactory = self._enemyEntityFactory,
		CombatPerceptionService = self:_BuildPerceptionProxy(),
		CurrentTime = currentTime,
		ProjectileService = self:_BuildProjectileProxy(entity),
	}
end

-- Adapts projectile firing so the runtime always emits structure-owned bullets.
function StructureCombatAdapterService:_BuildProjectileProxy(entity: number): any
	local projectileService = self._combatServices.ProjectileService
	return {
		FireStructureBullet = function(_proxy: any, request: any)
			return projectileService:FireStructureBullet({
				StructureEntity = entity,
				TargetEnemyEntity = request.TargetEnemyEntity,
				Damage = request.Damage,
				MaxDistance = request.MaxDistance,
			})
		end,
	}
end

-- Adapts the structure entity factory to the behavior runtime without exposing the raw entity id.
function StructureCombatAdapterService:_BuildStructureFactoryProxy(entity: number): any
	local factory = self._entityFactory
	return {
		IsActive = function(_proxy: any, _runtimeId: number): boolean
			return factory:IsActive(entity)
		end,
		GetPosition = function(_proxy: any, _runtimeId: number): Vector3?
			return factory:GetPosition(entity)
		end,
		GetAttackStats = function(_proxy: any, _runtimeId: number)
			return factory:GetAttackStats(entity)
		end,
		GetCooldown = function(_proxy: any, _runtimeId: number)
			return factory:GetCooldown(entity)
		end,
		SetCooldownElapsed = function(_proxy: any, _runtimeId: number, elapsed: number)
			factory:SetCooldownElapsed(entity, elapsed)
		end,
		SetTarget = function(_proxy: any, _runtimeId: number, targetEnemy: number?)
			factory:SetTarget(entity, targetEnemy)
		end,
		GetModelRef = function(_proxy: any, _runtimeId: number)
			return factory:GetModelRef(entity)
		end,
		PromoteToCommitted = function(_proxy: any, _runtimeId: number)
			factory:PromoteToCommitted(entity)
		end,
	}
end

-- Exposes range checks to behavior nodes through the shared combat perception interface.
function StructureCombatAdapterService:_BuildPerceptionProxy(): any
	return {
		IsTargetInRange = function(
			_proxy: any,
			position: Vector3,
			attackRange: number,
			targetKind: any,
			targetEntity: number?
		)
			if targetKind ~= "Enemy" or targetEntity == nil then
				return false
			end
			return self:_IsEnemyTargetInRange(position, attackRange, targetEntity)
		end,
	}
end

-- Finds the nearest enemy candidate that is still valid for the structure's attack range.
function StructureCombatAdapterService:_FindNearestEnemyInRange(
	position: Vector3,
	attackRange: number
): number?
	return SpatialQuery.FindBestCandidate(
		position,
		self._enemyEntityFactory:QueryAliveEntities(),
		function(enemyEntity: number): Vector3?
			local enemyCFrame = self._enemyEntityFactory:GetEntityCFrame(enemyEntity)
			return if enemyCFrame ~= nil then enemyCFrame.Position else nil
		end,
		function(enemyEntity: number, distance: number): number?
			if not self:_IsEnemyTargetInRange(position, attackRange, enemyEntity) then
				return nil
			end
			return -distance
		end,
		attackRange
	)
end

-- Resolves the enemy target model and performs the range test for structure attacks.
function StructureCombatAdapterService:_IsEnemyTargetInRange(
	position: Vector3,
	attackRange: number,
	enemyEntity: number
): boolean
	if not self._enemyEntityFactory:IsAlive(enemyEntity) then
		return false
	end

	local modelRef = self._enemyEntityFactory:GetModelRef(enemyEntity)
	if modelRef == nil or modelRef.Model == nil or modelRef.Model.Parent == nil then
		return false
	end

	return SpatialQuery.IsWithinRaycastRange(
		position,
		ModelPlus.GetCenterPosition(modelRef.Model),
		attackRange,
		SpatialQuery.MergeOptions(
			SpatialQuery.Presets.CharactersOnly,
			SpatialQuery.Presets.IncludeInstances({ modelRef.Model })
		),
		0.05
	)
end

-- Maps hit parts back to enemy entities for structure attack resolution.
function StructureCombatAdapterService:_ResolveHitEntity(hitPart: BasePart): any?
	local model = hitPart:FindFirstAncestorOfClass("Model")
	if model == nil then
		return nil
	end

	local enemyEntity = self._enemyInstanceFactory:GetEntity(model)
	if enemyEntity ~= nil then
		return {
			Kind = "Enemy",
			Entity = enemyEntity,
		}
	end

	return nil
end

return StructureCombatAdapterService
