--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)

local StructureActionExecutionSystem = {}
StructureActionExecutionSystem.__index = StructureActionExecutionSystem

local ACTION_ATTACK = "StructureAttack"
local ACTION_EXTRACT = "StructureExtract"
local ACTION_STASIS = "StructureStasis"
local ACTION_IDLE = "StructureIdle"

function StructureActionExecutionSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, StructureActionExecutionSystem)
	self._entityFactory = entityFactory
	self._entityContext = dependencies.EntityContext
	self._enemyContext = dependencies.EnemyContext
	self._combatContext = dependencies.CombatContext
	self._miningContext = dependencies.MiningContext
	self._lastRunAtByEntity = {}
	self._combatServices = nil
	self._enemyReadService = nil
	self._didConfigureCombatServices = false
	return self
end

function StructureActionExecutionSystem:Run()
	self:_ConfigureCombatServices()

	local queryResult = self._entityFactory:Query({
		FeatureName = "Structure",
		Keys = { "OperationalTag" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
end

function StructureActionExecutionSystem:_RunEntity(entity: number, now: number)
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	local actionIntent = self:_Get(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	if type(actionState) ~= "table" or actionState.Status ~= AISharedContract.ActionStatus.Running then
		self:_RemoveStasis(entity)
		return
	end
	if type(actionIntent) ~= "table" or actionIntent.SourceEntity ~= entity then
		self:_RemoveStasis(entity)
		return
	end

	local dt = math.max(0, now - (self._lastRunAtByEntity[entity] or now))
	self._lastRunAtByEntity[entity] = now

	if actionIntent.ActionId == ACTION_ATTACK then
		self:_RunAttack(entity, actionIntent, now)
	elseif actionIntent.ActionId == ACTION_STASIS then
		self:_RunStasis(entity)
	elseif actionIntent.ActionId == ACTION_EXTRACT then
		self:_RunExtract(entity, dt)
	elseif actionIntent.ActionId == ACTION_IDLE then
		self:_RunIdle(entity)
	else
		self:_RunIdle(entity)
	end
end

function StructureActionExecutionSystem:_RunAttack(entity: number, actionIntent: any, now: number)
	self:_RemoveStasis(entity)
	local targetEntity = actionIntent.TargetEntity
	if type(targetEntity) ~= "number" then
		self:_SetTarget(entity, nil)
		self:_SetPresentation(entity, "Idle", true, nil)
		return
	end

	local stats = self:_Get(entity, "Stats", "Structure")
	local identity = self:_Get(entity, "Identity", "Entity")
	if type(stats) ~= "table" or type(identity) ~= "table" then
		return
	end

	self:_SetTarget(entity, targetEntity)
	self:_SetPresentation(entity, "Attack", false, self:_ResolveEnemyId(targetEntity))

	local cooldown = if type(stats.AttackCooldown) == "number" then stats.AttackCooldown else 0
	local lastAttackAt = if type(stats.LastAttackAt) == "number" then stats.LastAttackAt else 0
	if now - lastAttackAt < cooldown then
		return
	end

	local combatServices = self:_GetCombatServices()
	if combatServices == nil or combatServices.ProjectileService == nil then
		return
	end

	local fireResult = combatServices.ProjectileService:FireStructureBullet({
		StructureEntity = entity,
		TargetEnemyEntity = targetEntity,
		Damage = stats.AttackDamage or 0,
		MaxDistance = stats.AttackRange or 0,
	})
	if fireResult.success ~= true then
		return
	end

	local nextStats = table.clone(stats)
	nextStats.LastAttackAt = now
	self._entityFactory:Set(entity, "Stats", nextStats, "Structure")
	self:_MarkDirty(entity)
end

function StructureActionExecutionSystem:_RunStasis(entity: number)
	local stats = self:_Get(entity, "Stats", "Structure")
	local position = self:_GetPosition(entity)
	if type(stats) ~= "table" or position == nil then
		return
	end

	local combatServices = self:_GetCombatServices()
	if combatServices == nil or combatServices.StatusService == nil then
		return
	end

	combatServices.StatusService:UpsertAuraSource(self:_BuildStructureHandle(entity), {
		SourceType = "StasisField",
		Position = position,
		Radius = stats.StasisRadius or 0,
		MoveSpeedMultiplier = stats.MoveSpeedMultiplier or 1,
		IsActive = true,
	})
	self:_SetPresentation(entity, "Stasis", true, nil)
end

function StructureActionExecutionSystem:_RunExtract(entity: number, dt: number)
	self:_RemoveStasis(entity)
	self:_SetPresentation(entity, "Extract", true, nil)
	if dt <= 0 or self._miningContext == nil then
		return
	end

	local sourcePlacement = self:_Get(entity, "SourcePlacement", "Structure")
	local instanceId = if type(sourcePlacement) == "table" then sourcePlacement.InstanceId else nil
	if type(instanceId) ~= "number" then
		return
	end

	local miningEntityResult = self._miningContext:GetExtractorEntityByInstanceId(instanceId)
	if not miningEntityResult.success or type(miningEntityResult.value) ~= "number" then
		return
	end
	local miningSystemResult = self._miningContext:GetExtractorMiningSystem()
	if not miningSystemResult.success or miningSystemResult.value == nil then
		return
	end

	miningSystemResult.value:AdvanceExtractor(miningEntityResult.value, dt)
end

function StructureActionExecutionSystem:_RunIdle(entity: number)
	self:_RemoveStasis(entity)
	self:_SetTarget(entity, nil)
	self:_SetPresentation(entity, "Idle", true, nil)
end

function StructureActionExecutionSystem:_ConfigureCombatServices()
	if self._didConfigureCombatServices then
		return
	end

	local combatServices = self:_GetCombatServices()
	if combatServices == nil then
		return
	end

	local enemyFactoryResult = self._enemyContext and self._enemyContext:GetEntityFactory() or nil
	if enemyFactoryResult ~= nil and enemyFactoryResult.success then
		self._enemyReadService = enemyFactoryResult.value
		if combatServices.StatusService ~= nil then
			combatServices.StatusService:ConfigureEnemyEntityFactory(self._enemyReadService)
		end
	end

	if combatServices.ProjectileService ~= nil then
		combatServices.ProjectileService:ConfigureStructureBulletResolver({
			ResolveStructureModel = function(structureEntity: number): Model?
				local boundResult = self._entityContext:GetBoundInstance(structureEntity)
				local instance = if boundResult.success then boundResult.value else nil
				return if instance ~= nil and instance:IsA("Model") then instance else nil
			end,
			ResolveEnemyCFrame = function(enemyEntity: number): CFrame?
				return if self._enemyReadService ~= nil then self._enemyReadService:GetEntityCFrame(enemyEntity) else nil
			end,
			ResolveEnemyEntity = function(hitPart: Instance): number?
				local boundEntityResult = self._entityContext:GetBoundEntity(hitPart)
				local entity = if boundEntityResult.success then boundEntityResult.value else nil
				return if type(entity) == "number" and self:_IsEnemyAlive(entity) then entity else nil
			end,
			IsEnemyAlive = function(enemyEntity: number): boolean
				return self:_IsEnemyAlive(enemyEntity)
			end,
			ApplyEnemyDamage = function(enemyEntity: number, damage: number)
				if self._enemyContext ~= nil then
					self._enemyContext:ApplyDamage(enemyEntity, damage)
				end
			end,
		})
	end

	self._didConfigureCombatServices = true
end

function StructureActionExecutionSystem:_GetCombatServices(): any?
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

function StructureActionExecutionSystem:_IsEnemyAlive(enemyEntity: number): boolean
	return self._enemyReadService ~= nil and self._enemyReadService:IsAlive(enemyEntity)
end

function StructureActionExecutionSystem:_ResolveEnemyId(enemyEntity: number): string?
	if self._enemyReadService == nil then
		return nil
	end
	local identity = self._enemyReadService:GetIdentity(enemyEntity)
	return if type(identity) == "table" and type(identity.EnemyId) == "string" then identity.EnemyId else nil
end

function StructureActionExecutionSystem:_GetPosition(entity: number): Vector3?
	local transform = self:_Get(entity, "Transform", "Entity")
	if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then
		return transform.CFrame.Position
	end
	return nil
end

function StructureActionExecutionSystem:_SetTarget(entity: number, targetEntity: number?)
	self._entityFactory:Set(entity, "Target", {
		TargetEntity = targetEntity,
		TargetKind = if targetEntity ~= nil then "Enemy" else nil,
	}, "Entity")
	self:_MarkDirty(entity)
end

function StructureActionExecutionSystem:_SetPresentation(
	entity: number,
	animationState: string,
	isLooping: boolean,
	targetEnemyId: string?
)
	self._entityFactory:Set(entity, "AnimationState", animationState, "Structure")
	self._entityFactory:Set(entity, "AnimationLooping", isLooping, "Structure")
	self._entityFactory:Set(entity, "TargetEnemyId", targetEnemyId, "Structure")
	self:_MarkDirty(entity)
end

function StructureActionExecutionSystem:_RemoveStasis(entity: number)
	local combatServices = self:_GetCombatServices()
	if combatServices ~= nil and combatServices.StatusService ~= nil then
		combatServices.StatusService:RemoveAuraSource(self:_BuildStructureHandle(entity))
	end
end

function StructureActionExecutionSystem:_BuildStructureHandle(entity: number): string
	local identity = self:_Get(entity, "Identity", "Entity")
	if type(identity) == "table" and type(identity.EntityId) == "string" then
		return "Structure:" .. identity.EntityId
	end
	return "Structure:" .. tostring(entity)
end

function StructureActionExecutionSystem:_Get(entity: number, key: string, featureName: string?): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function StructureActionExecutionSystem:_MarkDirty(entity: number)
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

return StructureActionExecutionSystem
