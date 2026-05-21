--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseECSEntityFactory = require(ServerStorage.Utilities.ECSUtilities.BaseECSEntityFactory)
local SummonTypes = require(ReplicatedStorage.Contexts.Summon.Types.SummonTypes)

type SwarmTuning = SummonTypes.SwarmTuning

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
	return setmetatable(BaseECSEntityFactory.new("Summon"), SummonEntityFactory)
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
	self:RegisterBucketLookupIndex("OwnerUserId")
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
		MoveSpeed = tuning.MoveSpeed,
		AcquireRange = tuning.AcquireRange,
		AttackRange = tuning.AttackRange,
		AttackInterval = tuning.AttackInterval,
		DamagePerHit = tuning.DamagePerHit,
		LastAttackAt = 0,
	} :: CombatComponent)

	self:_Set(entity, self._components.LifetimeComponent, {
		SpawnedAt = now,
		ExpiresAt = now + tuning.Lifetime,
	} :: LifetimeComponent)

	self:_Add(entity, self._components.ActiveTag)
	self:SetBucketLookup("OwnerUserId", ownerUserId, entity)

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
	return self:GetBucketLookupKey("OwnerUserId", entity)
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
	return self:QueryBucketLookup("OwnerUserId", ownerUserId)
end

function SummonEntityFactory:GetOwnerDroneCount(ownerUserId: number): number
	self:RequireReady()
	return self:GetBucketLookupCount("OwnerUserId", ownerUserId)
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

	self:ClearBucketLookup("OwnerUserId", entity)
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
