--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
type SwarmTuning = {
	summonCount: number,
	lifetime: number,
	maxConcurrentDronesPerPlayer: number,
	moveSpeed: number,
	acquireRange: number,
	attackRange: number,
	attackInterval: number,
	damagePerHit: number,
}

type IdentityComponent = {
	OwnerUserId: number,
	DroneId: string,
}

type PositionComponent = {
	CFrame: CFrame,
}

type CombatComponent = {
	MoveSpeed: number,
	AcquireRange: number,
	AttackRange: number,
	AttackInterval: number,
	DamagePerHit: number,
	LastAttackAt: number,
}

type LifetimeComponent = {
	SpawnedAt: number,
	ExpiresAt: number,
}

type InstanceRefComponent = {
	Instance: BasePart,
}

local SummonEntityFactory = {}
SummonEntityFactory.__index = SummonEntityFactory
setmetatable(SummonEntityFactory, { __index = BaseECSEntityFactory })

local function _nextDroneId(ownerUserId: number, entity: number): string
	return string.format("%d-%d", ownerUserId, entity)
end

function SummonEntityFactory.new()
	local self = setmetatable(BaseECSEntityFactory.new("Summon"), SummonEntityFactory)
	self._ownerEntities = {} :: { [number]: { [number]: true } }
	self._ownerByEntity = {} :: { [number]: number }
	return self
end

function SummonEntityFactory:_GetComponentRegistryName(): string
	return "SummonComponentRegistry"
end

function SummonEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(
		self._components ~= nil
			and self._components.IdentityComponent ~= nil
			and self._components.PositionComponent ~= nil
			and self._components.CombatComponent ~= nil
			and self._components.LifetimeComponent ~= nil
			and self._components.InstanceRefComponent ~= nil
			and self._components.ActiveTag ~= nil,
		"SummonEntityFactory: missing SummonComponentRegistry components"
	)
end

function SummonEntityFactory:_TrackOwnerEntity(ownerUserId: number, entity: number)
	local ownerSet = self._ownerEntities[ownerUserId]
	if ownerSet == nil then
		ownerSet = {}
		self._ownerEntities[ownerUserId] = ownerSet
	end
	ownerSet[entity] = true
	self._ownerByEntity[entity] = ownerUserId
end

function SummonEntityFactory:_UntrackOwnerEntity(entity: number)
	local ownerUserId = self._ownerByEntity[entity]
	if ownerUserId == nil then
		return
	end

	self._ownerByEntity[entity] = nil
	local ownerSet = self._ownerEntities[ownerUserId]
	if ownerSet == nil then
		return
	end

	ownerSet[entity] = nil
	if next(ownerSet) == nil then
		self._ownerEntities[ownerUserId] = nil
	end
end

function SummonEntityFactory:CreateDrone(ownerUserId: number, spawnCFrame: CFrame, now: number, tuning: SwarmTuning): number
	self:RequireReady()
	local entity = self:_CreateEntity()

	self:_Set(entity, self._components.IdentityComponent, {
		OwnerUserId = ownerUserId,
		DroneId = _nextDroneId(ownerUserId, entity),
	} :: IdentityComponent)

	self:_Set(entity, self._components.PositionComponent, {
		CFrame = spawnCFrame,
	} :: PositionComponent)

	self:_Set(entity, self._components.CombatComponent, {
		MoveSpeed = tuning.moveSpeed,
		AcquireRange = tuning.acquireRange,
		AttackRange = tuning.attackRange,
		AttackInterval = tuning.attackInterval,
		DamagePerHit = tuning.damagePerHit,
		LastAttackAt = 0,
	} :: CombatComponent)

	self:_Set(entity, self._components.LifetimeComponent, {
		SpawnedAt = now,
		ExpiresAt = now + tuning.lifetime,
	} :: LifetimeComponent)

	self:_Add(entity, self._components.ActiveTag)
	self:_TrackOwnerEntity(ownerUserId, entity)

	return entity
end

function SummonEntityFactory:SetInstanceRef(entity: number, instance: BasePart)
	self:RequireReady()
	self:_Set(entity, self._components.InstanceRefComponent, {
		Instance = instance,
	} :: InstanceRefComponent)
end

function SummonEntityFactory:GetInstanceRef(entity: number): BasePart?
	self:RequireReady()
	local component = self:_Get(entity, self._components.InstanceRefComponent) :: InstanceRefComponent?
	if component == nil then
		return nil
	end
	return component.Instance
end

function SummonEntityFactory:GetIdentity(entity: number): IdentityComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.IdentityComponent)
end

function SummonEntityFactory:GetOwnerUserId(entity: number): number?
	self:RequireReady()
	return self._ownerByEntity[entity]
end

function SummonEntityFactory:GetPosition(entity: number): CFrame?
	self:RequireReady()
	local component = self:_Get(entity, self._components.PositionComponent) :: PositionComponent?
	if component == nil then
		return nil
	end
	return component.CFrame
end

function SummonEntityFactory:SetPosition(entity: number, nextCFrame: CFrame)
	self:RequireReady()
	self:_Set(entity, self._components.PositionComponent, {
		CFrame = nextCFrame,
	} :: PositionComponent)
end

function SummonEntityFactory:GetCombat(entity: number): CombatComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.CombatComponent)
end

function SummonEntityFactory:SetLastAttackAt(entity: number, lastAttackAt: number)
	self:RequireReady()
	local combat = self:GetCombat(entity)
	if combat == nil then
		return
	end

	self:_Set(entity, self._components.CombatComponent, {
		MoveSpeed = combat.MoveSpeed,
		AcquireRange = combat.AcquireRange,
		AttackRange = combat.AttackRange,
		AttackInterval = combat.AttackInterval,
		DamagePerHit = combat.DamagePerHit,
		LastAttackAt = lastAttackAt,
	} :: CombatComponent)
end

function SummonEntityFactory:GetLifetime(entity: number): LifetimeComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.LifetimeComponent)
end

function SummonEntityFactory:IsActive(entity: number): boolean
	self:RequireReady()
	return self:_Has(entity, self._components.ActiveTag)
end

function SummonEntityFactory:QueryActiveEntities(): { number }
	self:RequireReady()
	return self:CollectQuery(self._components.ActiveTag)
end

function SummonEntityFactory:QueryOwnerEntities(ownerUserId: number): { number }
	self:RequireReady()
	local ownerSet = self._ownerEntities[ownerUserId]
	if ownerSet == nil then
		return {}
	end

	local entities = {}
	for entity in ownerSet do
		if self:_Exists(entity) and self:IsActive(entity) then
			table.insert(entities, entity)
		end
	end
	return entities
end

function SummonEntityFactory:GetOwnerDroneCount(ownerUserId: number): number
	self:RequireReady()
	return #self:QueryOwnerEntities(ownerUserId)
end

function SummonEntityFactory:DeleteEntity(entity: number?)
	self:RequireReady()
	if entity == nil or not self:_Exists(entity) then
		return
	end

	local instance = self:GetInstanceRef(entity)
	if instance ~= nil then
		instance:Destroy()
	end

	if self:_Has(entity, self._components.ActiveTag) then
		self:_Remove(entity, self._components.ActiveTag)
	end

	self:_UntrackOwnerEntity(entity)
	self:MarkForDestruction(entity)
end

function SummonEntityFactory:DeleteAll()
	self:RequireReady()
	for _, entity in ipairs(self:QueryActiveEntities()) do
		self:DeleteEntity(entity)
	end
end

function SummonEntityFactory:DeleteOwnerSummons(ownerUserId: number)
	self:RequireReady()
	for _, entity in ipairs(self:QueryOwnerEntities(ownerUserId)) do
		self:DeleteEntity(entity)
	end
end

function SummonEntityFactory:FlushPendingDeletes(): boolean
	self:RequireReady()
	return self:FlushDestructionQueue()
end

return SummonEntityFactory
