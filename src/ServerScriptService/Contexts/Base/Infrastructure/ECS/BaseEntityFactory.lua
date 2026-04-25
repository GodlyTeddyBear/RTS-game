--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

type BaseState = BaseTypes.BaseState
type HealthComponent = BaseTypes.HealthComponent
type InstanceRefComponent = BaseTypes.InstanceRefComponent
type IdentityComponent = BaseTypes.IdentityComponent

local BaseEntityFactory = {}
BaseEntityFactory.__index = BaseEntityFactory
setmetatable(BaseEntityFactory, { __index = BaseECSEntityFactory })

function BaseEntityFactory.new()
	local self = setmetatable(BaseECSEntityFactory.new("Base"), BaseEntityFactory)
	self._baseEntity = nil :: number?
	return self
end

function BaseEntityFactory:_GetComponentRegistryName(): string
	return "BaseComponentRegistry"
end

function BaseEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(
		self._components ~= nil
			and self._components.HealthComponent ~= nil
			and self._components.InstanceRefComponent ~= nil
			and self._components.IdentityComponent ~= nil
			and self._components.ActiveTag ~= nil,
		"BaseEntityFactory: missing BaseComponentRegistry components"
	)
end

function BaseEntityFactory:CreateOrResetBase(baseId: string, maxHp: number, instance: Instance, anchor: BasePart): number
	self:RequireReady()

	local entity = self._baseEntity
	if entity == nil then
		entity = self:_CreateEntity()
		self._baseEntity = entity
	end

	self:_Set(entity, self._components.IdentityComponent, {
		BaseId = baseId,
	} :: IdentityComponent)
	self:_Set(entity, self._components.HealthComponent, {
		hp = maxHp,
		maxHp = maxHp,
	} :: HealthComponent)
	self:_Set(entity, self._components.InstanceRefComponent, {
		Instance = instance,
		Anchor = anchor,
	} :: InstanceRefComponent)
	self:_Add(entity, self._components.ActiveTag)

	return entity
end

function BaseEntityFactory:GetBaseEntity(): number?
	self:RequireReady()
	return self._baseEntity
end

function BaseEntityFactory:GetHealth(): HealthComponent?
	self:RequireReady()
	local entity = self._baseEntity
	if entity == nil then
		return nil
	end

	return self:_Get(entity, self._components.HealthComponent)
end

function BaseEntityFactory:GetBaseState(): BaseState?
	local health = self:GetHealth()
	if health == nil then
		return nil
	end

	return {
		hp = health.hp,
		maxHp = health.maxHp,
	}
end

function BaseEntityFactory:GetInstanceRef(): InstanceRefComponent?
	self:RequireReady()
	local entity = self._baseEntity
	if entity == nil then
		return nil
	end

	return self:_Get(entity, self._components.InstanceRefComponent)
end

function BaseEntityFactory:GetTargetCFrame(): CFrame?
	local ref = self:GetInstanceRef()
	if ref == nil then
		return nil
	end

	return ref.Anchor.CFrame
end

function BaseEntityFactory:GetModel(): Model?
	local ref = self:GetInstanceRef()
	if ref == nil then
		return nil
	end

	if ref.Instance:IsA("Model") then
		return ref.Instance
	end

	return ref.Instance:FindFirstAncestorOfClass("Model")
end

function BaseEntityFactory:IsPartOfBase(instance: Instance): boolean
	local ref = self:GetInstanceRef()
	if ref == nil then
		return false
	end

	return instance == ref.Instance or instance:IsDescendantOf(ref.Instance)
end

function BaseEntityFactory:IsActive(): boolean
	self:RequireReady()
	local entity = self._baseEntity
	return entity ~= nil and self:_Has(entity, self._components.ActiveTag)
end

function BaseEntityFactory:ApplyDamage(amount: number): boolean
	self:RequireReady()
	local entity = self._baseEntity
	if entity == nil then
		return false
	end

	local health = self:GetHealth()
	if health == nil then
		return false
	end

	local nextHp = math.max(0, health.hp - amount)
	self:_Set(entity, self._components.HealthComponent, {
		hp = nextHp,
		maxHp = health.maxHp,
	} :: HealthComponent)

	return nextHp <= 0
end

function BaseEntityFactory:ClearBase()
	self:RequireReady()
	local entity = self._baseEntity
	if entity == nil then
		return
	end

	if self:_Has(entity, self._components.ActiveTag) then
		self:_Remove(entity, self._components.ActiveTag)
	end

	self:MarkForDestruction(entity)
	self:FlushDestructionQueue()
	self._baseEntity = nil
end

return BaseEntityFactory
