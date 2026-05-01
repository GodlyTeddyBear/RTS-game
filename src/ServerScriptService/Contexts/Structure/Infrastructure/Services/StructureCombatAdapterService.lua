--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local StructureAttackExecutor = require(script.Parent.Parent.BehaviorSystem.Executors.StructureAttackExecutor)
local StructureBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.StructureBehavior)

local StructureCombatAdapterService = {}
StructureCombatAdapterService.__index = StructureCombatAdapterService

function StructureCombatAdapterService.new()
	local self = setmetatable({}, StructureCombatAdapterService)
	self._configuredCombatServices = false
	return self
end

function StructureCombatAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("StructureEntityFactory")
end

function StructureCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._enemyContext = registry:Get("EnemyContext")
	self._enemyEntityFactory = self._enemyContext:GetEntityFactory().value
	self._enemyInstanceFactory = self._enemyContext:GetInstanceFactory().value
	self._combatServices = self._combatContext:GetCombatRuntimeServices().value
	self:_ConfigureCombatServices()
end

function StructureCombatAdapterService:RegisterActorType(): Result.Result<boolean>
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
	})
end

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
		},
	})
end

function StructureCombatAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
end

function StructureCombatAdapterService:_ConfigureCombatServices()
	if self._configuredCombatServices then
		return
	end

	self._combatServices.HitboxService:RegisterTargetResolver(function(hitPart: BasePart): any?
		return self:_ResolveHitEntity(hitPart)
	end)
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

function StructureCombatAdapterService:_BuildActorHandle(entity: number): string
	local identity = self._entityFactory:GetIdentity(entity)
	if identity ~= nil and type(identity.StructureId) == "string" then
		return "Structure:" .. identity.StructureId
	end
	return "Structure:" .. tostring(entity)
end

function StructureCombatAdapterService:_BuildFacts(entity: number): { [string]: any }
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

function StructureCombatAdapterService:_BuildServices(entity: number, currentTime: number): { [string]: any }
	return {
		StructureEntityFactory = self:_BuildStructureFactoryProxy(entity),
		EnemyEntityFactory = self._enemyEntityFactory,
		CombatPerceptionService = self:_BuildPerceptionProxy(),
		CurrentTime = currentTime,
		ProjectileService = self:_BuildProjectileProxy(entity),
	}
end

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

function StructureCombatAdapterService:_BuildPerceptionProxy(): any
	return {
		IsTargetInRange = function(_proxy: any, position: Vector3, attackRange: number, targetKind: any, targetEntity: number?)
			if targetKind ~= "Enemy" or targetEntity == nil then
				return false
			end
			return self:_IsEnemyTargetInRange(position, attackRange, targetEntity)
		end,
	}
end

function StructureCombatAdapterService:_FindNearestEnemyInRange(position: Vector3, attackRange: number): number?
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
		SpatialQuery.MergeOptions(SpatialQuery.Presets.CharactersOnly, SpatialQuery.Presets.IncludeInstances({ modelRef.Model })),
		0.05
	)
end

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
