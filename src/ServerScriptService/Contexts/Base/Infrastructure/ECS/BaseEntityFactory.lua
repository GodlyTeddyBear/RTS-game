--!strict

--[=[
    @class BaseEntityFactory
    Owns the Base context's single ECS entity and exposes base state accessors.
    @server
]=]

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

--[=[
    Create a new base entity factory.
    @within BaseEntityFactory
    @return BaseEntityFactory -- Factory instance.
]=]
function BaseEntityFactory.new()
	local self = setmetatable(BaseECSEntityFactory.new("Base"), BaseEntityFactory)
	self._baseEntity = nil :: number?
	return self
end

-- Returns the component registry name used by the Base entity factory.
function BaseEntityFactory:_GetComponentRegistryName(): string
	return "BaseComponentRegistry"
end

-- Verifies that the Base component registry exposed all required components.
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

--[=[
    Create or reset the singleton base entity.
    @within BaseEntityFactory
    @param baseId string -- Stable base identifier stored on the identity component.
    @param maxHp number -- Maximum hit points assigned to the base.
    @param instance Instance -- Runtime base instance.
    @param anchor BasePart -- Anchor part used to resolve the target CFrame.
    @return number -- The base entity identifier.
]=]
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

--[=[
    Return the current base entity identifier.
    @within BaseEntityFactory
    @return number? -- Base entity identifier when the base exists.
]=]
function BaseEntityFactory:GetBaseEntity(): number?
	self:RequireReady()
	return self._baseEntity
end

--[=[
    Return the active base health component.
    @within BaseEntityFactory
    @return HealthComponent? -- Current health component when the base exists.
]=]
function BaseEntityFactory:GetHealth(): HealthComponent?
	self:RequireReady()
	local entity = self._baseEntity
	if entity == nil then
		return nil
	end

	return self:_Get(entity, self._components.HealthComponent)
end

--[=[
    Return the current base state snapshot.
    @within BaseEntityFactory
    @return BaseState? -- Copy of the base state when the base exists.
]=]
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

--[=[
    Return the active base instance reference component.
    @within BaseEntityFactory
    @return InstanceRefComponent? -- Current instance reference when the base exists.
]=]
function BaseEntityFactory:GetInstanceRef(): InstanceRefComponent?
	self:RequireReady()
	local entity = self._baseEntity
	if entity == nil then
		return nil
	end

	return self:_Get(entity, self._components.InstanceRefComponent)
end

--[=[
    Return the base anchor CFrame.
    @within BaseEntityFactory
    @return CFrame? -- Anchor CFrame when the base exists.
]=]
function BaseEntityFactory:GetTargetCFrame(): CFrame?
	local ref = self:GetInstanceRef()
	if ref == nil then
		return nil
	end

	return ref.Anchor.CFrame
end

--[=[
    Return the base model when the stored instance resolves to one.
    @within BaseEntityFactory
    @return Model? -- Base model or the nearest ancestor model.
]=]
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

--[=[
    Check whether an instance belongs to the active base.
    @within BaseEntityFactory
    @param instance Instance -- Instance to test against the stored base instance.
    @return boolean -- Whether the instance is part of the base.
]=]
function BaseEntityFactory:IsPartOfBase(instance: Instance): boolean
	local ref = self:GetInstanceRef()
	if ref == nil then
		return false
	end

	return instance == ref.Instance or instance:IsDescendantOf(ref.Instance)
end

--[=[
    Check whether the base entity is active.
    @within BaseEntityFactory
    @return boolean -- Whether the active tag is present on the base entity.
]=]
function BaseEntityFactory:IsActive(): boolean
	self:RequireReady()
	local entity = self._baseEntity
	return entity ~= nil and self:_Has(entity, self._components.ActiveTag)
end

--[=[
    Apply damage to the active base entity.
    @within BaseEntityFactory
    @param amount number -- Damage amount to subtract from the current HP.
    @return boolean -- Whether the base reached zero HP.
]=]
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

--[=[
    Clear the active base entity and queue it for destruction.
    @within BaseEntityFactory
]=]
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
