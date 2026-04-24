--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)
local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)

type StructureType = StructureTypes.StructureType
type TAttackStatsComponent = StructureTypes.TAttackStatsComponent
type TAttackCooldownComponent = StructureTypes.TAttackCooldownComponent
type THealthComponent = StructureTypes.THealthComponent
type TIdentityComponent = StructureTypes.TIdentityComponent
type TInstanceRefComponent = StructureTypes.TInstanceRefComponent
type ResolvedStructureRecord = StructureTypes.ResolvedStructureRecord
type TCombatAction = ExecutorTypes.TCombatActionComponent

--[=[
	@class StructureEntityFactory
	Creates and mutates structure entities in the StructureContext ECS world.
	@server
]=]
local StructureEntityFactory = {}
StructureEntityFactory.__index = StructureEntityFactory
setmetatable(StructureEntityFactory, { __index = BaseECSEntityFactory })

local function _buildDefaultAction(): TCombatAction
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

--[=[
	Creates a new entity factory wrapper.
	@within StructureEntityFactory
	@return StructureEntityFactory -- The new factory instance.
]=]
function StructureEntityFactory.new()
	return setmetatable(BaseECSEntityFactory.new("Structure"), StructureEntityFactory)
end

--[=[
	Caches the world and component ids for later entity operations.
	@within StructureEntityFactory
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function StructureEntityFactory:_GetComponentRegistryName(): string
	return "StructureComponentRegistry"
end

function StructureEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(
		self._components ~= nil
			and self._components.AttackStatsComponent ~= nil
			and self._components.AttackCooldownComponent ~= nil
			and self._components.HealthComponent ~= nil
			and self._components.TargetComponent ~= nil
			and self._components.BehaviorTreeComponent ~= nil
			and self._components.CombatActionComponent ~= nil
			and self._components.InstanceRefComponent ~= nil
			and self._components.ModelRefComponent ~= nil
			and self._components.IdentityComponent ~= nil
			and self._components.ActiveTag ~= nil,
		"StructureEntityFactory: missing StructureComponentRegistry components"
	)
end

--[=[
	Creates a structure entity from a resolved placement record.
	@within StructureEntityFactory
	@param record ResolvedStructureRecord -- The validated placement data.
	@return number -- The new ECS entity id.
]=]
function StructureEntityFactory:CreateStructure(record: ResolvedStructureRecord): number
	local components = self:GetComponentsOrThrow()

	local structureConfig = StructureConfig.STRUCTURES[record.structureType]
	assert(structureConfig ~= nil, "Unknown structure type: " .. tostring(record.structureType))

	-- Create the entity first so every component write targets the same ECS id.
	local entity = self:_CreateEntity()
	local structureId = tostring(record.instanceId)

	-- Copy the combat stats from config so later balance changes stay data-driven.
	self:_Set(entity, components.AttackStatsComponent, {
		AttackRange = structureConfig.AttackRange,
		AttackDamage = structureConfig.AttackDamage,
		AttackCooldown = structureConfig.AttackCooldown,
	} :: TAttackStatsComponent)

	-- Start ready so the first acquired target can be attacked immediately.
	self:_Set(entity, components.AttackCooldownComponent, {
		Elapsed = structureConfig.AttackCooldown,
	} :: TAttackCooldownComponent)

	self:_Set(entity, components.HealthComponent, {
		Current = structureConfig.MaxHealth,
		Max = structureConfig.MaxHealth,
	} :: THealthComponent)

	-- Store a nil target until the targeting system resolves a nearby enemy.
	self:_Set(entity, components.TargetComponent, {
		Entity = nil,
	})

	self:_Set(entity, components.CombatActionComponent, _buildDefaultAction())

	-- Persist the runtime instance id and world-space anchor for targeting queries.
	self:_Set(entity, components.InstanceRefComponent, {
		InstanceId = record.instanceId,
		WorldPos = record.worldPos,
	} :: TInstanceRefComponent)

	-- Keep the canonical identity separate from the runtime instance ref.
	self:_Set(entity, components.IdentityComponent, {
		StructureId = structureId,
		StructureType = record.structureType,
	} :: TIdentityComponent)

	-- Mark the entity active so queries and systems can pick it up this frame.
	self:_Add(entity, components.ActiveTag)
	return entity
end

--[=[
	Sets or clears the current target for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to mutate.
	@param targetEntity number? -- The target entity or `nil` to clear.
]=]
-- Updates or clears the current attack target for a structure entity.
function StructureEntityFactory:SetTarget(entity: number?, targetEntity: number?)
	if entity == nil then
		return
	end

	local components = self:GetComponentsOrThrow()

	self:_Set(entity, components.TargetComponent, {
		Entity = targetEntity,
	})
end

--[=[
	Returns the current target entity for a structure.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return number? -- The targeted enemy entity or `nil`.
]=]
function StructureEntityFactory:GetTarget(entity: number?): number?
	if entity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()

	local targetComponent = self:_Get(entity, components.TargetComponent)
	if targetComponent == nil then
		return nil
	end

	return targetComponent.Entity
end

--[=[
	Returns the attack stats component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return TAttackStatsComponent? -- The attack stats or `nil`.
]=]
function StructureEntityFactory:GetAttackStats(entity: number?): TAttackStatsComponent?
	if entity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()

	return self:_Get(entity, components.AttackStatsComponent)
end

--[=[
	Returns the attack cooldown component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return TAttackCooldownComponent? -- The cooldown state or `nil`.
]=]
function StructureEntityFactory:GetCooldown(entity: number?): TAttackCooldownComponent?
	if entity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()

	return self:_Get(entity, components.AttackCooldownComponent)
end

--[=[
	Returns the health component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return THealthComponent? -- The health state or `nil`.
]=]
function StructureEntityFactory:GetHealth(entity: number?): THealthComponent?
	if entity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()

	return self:_Get(entity, components.HealthComponent)
end

--[=[
	Sets the elapsed cooldown value for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to mutate.
	@param elapsed number -- The new elapsed cooldown in seconds.
]=]
function StructureEntityFactory:SetCooldownElapsed(entity: number?, elapsed: number)
	if entity == nil then
		return
	end

	-- Read the current component first so we can preserve the entity when it has already been removed.
	local current = self:GetCooldown(entity)
	if current == nil then
		return
	end

	local components = self:GetComponentsOrThrow()

	self:_Set(entity, components.AttackCooldownComponent, {
		Elapsed = elapsed,
	} :: TAttackCooldownComponent)
end

function StructureEntityFactory:SetBehaviorTree(entity: number, treeInstance: any, tickInterval: number)
	local components = self:GetComponentsOrThrow()

	self:_Set(entity, components.BehaviorTreeComponent, {
		TreeInstance = treeInstance,
		TickInterval = tickInterval,
		LastTickTime = 0,
	})
end

function StructureEntityFactory:GetBehaviorTree(entity: number)
	local components = self:GetComponentsOrThrow()

	return self:_Get(entity, components.BehaviorTreeComponent)
end

function StructureEntityFactory:UpdateBTLastTickTime(entity: number, currentTime: number)
	local behaviorTree = self:GetBehaviorTree(entity)
	if behaviorTree == nil then
		return
	end

	local components = self:GetComponentsOrThrow()

	self:_Set(entity, components.BehaviorTreeComponent, {
		TreeInstance = behaviorTree.TreeInstance,
		TickInterval = behaviorTree.TickInterval,
		LastTickTime = currentTime,
	})
end

function StructureEntityFactory:GetCombatAction(entity: number)
	local components = self:GetComponentsOrThrow()

	return self:_Get(entity, components.CombatActionComponent)
end

function StructureEntityFactory:SetCombatAction(entity: number, action: TCombatAction)
	local components = self:GetComponentsOrThrow()

	self:_Set(entity, components.CombatActionComponent, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = action.PendingActionId,
		PendingActionData = action.PendingActionData,
		StartedAt = action.StartedAt,
		FinishedAt = action.FinishedAt,
	})
end

function StructureEntityFactory:SetPendingAction(entity: number, actionId: string, actionData: any?)
	local action = self:GetCombatAction(entity) or _buildDefaultAction()
	self:SetCombatAction(entity, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = actionId,
		PendingActionData = actionData,
		StartedAt = action.StartedAt,
		FinishedAt = action.FinishedAt,
	})
end

function StructureEntityFactory:ClearPendingAction(entity: number)
	local action = self:GetCombatAction(entity) or _buildDefaultAction()
	self:SetCombatAction(entity, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = nil,
		PendingActionData = nil,
		StartedAt = action.StartedAt,
		FinishedAt = action.FinishedAt,
	})
end

function StructureEntityFactory:StartAction(entity: number, actionId: string, actionData: any?, currentTime: number)
	self:SetCombatAction(entity, {
		CurrentActionId = actionId,
		ActionState = "Running",
		ActionData = actionData,
		PendingActionId = nil,
		PendingActionData = nil,
		StartedAt = currentTime,
		FinishedAt = nil,
	})
end

function StructureEntityFactory:ClearAction(entity: number)
	self:SetCombatAction(entity, _buildDefaultAction())
end

function StructureEntityFactory:ResetActionState(entity: number)
	self:SetCombatAction(entity, _buildDefaultAction())
end

function StructureEntityFactory:ApplyDamage(entity: number, amount: number): boolean
	local health = self:GetHealth(entity)
	if health == nil then
		return false
	end

	local nextHp = math.max(0, health.Current - amount)
	local components = self:GetComponentsOrThrow()

	self:_Set(entity, components.HealthComponent, {
		Current = nextHp,
		Max = health.Max,
	} :: THealthComponent)

	return nextHp <= 0
end

--[=[
	Returns the identity component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return TIdentityComponent? -- The identity data or `nil`.
]=]
function StructureEntityFactory:GetIdentity(entity: number?): TIdentityComponent?
	if entity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()

	return self:_Get(entity, components.IdentityComponent)
end

--[=[
	Returns the instance reference component for a structure entity.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to inspect.
	@return TInstanceRefComponent? -- The instance reference or `nil`.
]=]
function StructureEntityFactory:GetInstanceRef(entity: number?): TInstanceRefComponent?
	if entity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()

	return self:_Get(entity, components.InstanceRefComponent)
end

function StructureEntityFactory:SetModelRef(entity: number?, model: Model)
	if entity == nil then
		return
	end

	local components = self:GetComponentsOrThrow()
	self:_Set(entity, components.ModelRefComponent, {
		model = model,
	})
end

function StructureEntityFactory:ClearModelRef(entity: number?)
	if entity == nil then
		return
	end

	local components = self:GetComponentsOrThrow()
	self:_Remove(entity, components.ModelRefComponent)
end

function StructureEntityFactory:GetModelRef(entity: number?): { model: Model }?
	if entity == nil then
		return nil
	end

	local components = self:GetComponentsOrThrow()
	return self:_Get(entity, components.ModelRefComponent)
end

function StructureEntityFactory:GetEntityByModel(model: Model): number?
	for _, entity in ipairs(self:QueryActiveEntities()) do
		local modelRef = self:GetModelRef(entity)
		if modelRef ~= nil and modelRef.model == model then
			return entity
		end
	end

	return nil
end

function StructureEntityFactory:GetPosition(entity: number?): Vector3?
	local instanceRef = self:GetInstanceRef(entity)
	if instanceRef == nil then
		return nil
	end

	return instanceRef.WorldPos
end

function StructureEntityFactory:IsActive(entity: number?): boolean
	if entity == nil then
		return false
	end

	local components = self:GetComponentsOrThrow()

	return self:_Has(entity, components.ActiveTag)
end

--[=[
	Collects every active structure entity into an array.
	@within StructureEntityFactory
	@return { number } -- All active structure entity ids.
]=]
function StructureEntityFactory:QueryActiveEntities(): { number }
	local components = self:GetComponentsOrThrow()

	return self:CollectQuery(components.ActiveTag)
end

--[=[
	Deletes a single structure entity if it still exists.
	@within StructureEntityFactory
	@param entity number? -- The ECS entity to delete.
]=]
function StructureEntityFactory:DeleteEntity(entity: number?)
	if entity == nil then
		return
	end

	local components = self:GetComponentsOrThrow()
	if self:_Has(entity, components.ActiveTag) then
		self:_Remove(entity, components.ActiveTag)
	end

	self:MarkForDestruction(entity)
end

--[=[
	Deletes every active structure entity.
	@within StructureEntityFactory
]=]
function StructureEntityFactory:DeleteAll()
	for _, entity in ipairs(self:QueryActiveEntities()) do
		self:DeleteEntity(entity)
	end
end

--[=[
	Flushes deferred structure entity deletions.
	@within StructureEntityFactory
	@return boolean -- True when at least one entity was deleted.
]=]
function StructureEntityFactory:FlushPendingDeletes(): boolean
	return self:FlushDestructionQueue()
end

return StructureEntityFactory
