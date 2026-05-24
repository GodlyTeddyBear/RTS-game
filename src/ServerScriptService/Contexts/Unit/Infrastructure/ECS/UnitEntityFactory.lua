--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseECSEntityFactory = require(ServerStorage.Utilities.ECSUtilities.BaseECSEntityFactory)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local UnitRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.UnitRuntimeProfiles)

type UnitDefinition = UnitTypes.UnitDefinition
type SpawnUnitRequest = UnitTypes.SpawnUnitRequest
type IdentityComponent = UnitTypes.IdentityComponent
type OwnershipComponent = UnitTypes.OwnershipComponent
type TransformComponent = UnitTypes.TransformComponent
type HealthComponent = UnitTypes.HealthComponent
type MoveSpeedComponent = UnitTypes.MoveSpeedComponent
type AnimationStateComponent = UnitTypes.AnimationStateComponent
type AnimationLoopingComponent = UnitTypes.AnimationLoopingComponent
type RoleComponent = UnitTypes.RoleComponent
type PathStateComponent = UnitTypes.PathStateComponent
type LifetimeComponent = UnitTypes.LifetimeComponent

local UnitEntityFactory = {}
UnitEntityFactory.__index = UnitEntityFactory
setmetatable(UnitEntityFactory, { __index = BaseECSEntityFactory })

local function _ownerKey(ownerKind: string, ownerId: string): string
	return ownerKind .. ":" .. ownerId
end

function UnitEntityFactory.new()
	return setmetatable(BaseECSEntityFactory.new("Unit"), UnitEntityFactory)
end

function UnitEntityFactory:_GetComponentRegistryName(): string
	return "UnitComponentRegistry"
end

function UnitEntityFactory:_OnInit(_registry: any, _name: string, _componentRegistry: any)
	assert(
		self._components ~= nil
			and self._components.IdentityComponent ~= nil
			and self._components.OwnershipComponent ~= nil
			and self._components.TransformComponent ~= nil
			and self._components.HealthComponent ~= nil
			and self._components.BaseMoveSpeedComponent ~= nil
			and self._components.CurrentMoveSpeedComponent ~= nil
			and self._components.PathStateComponent ~= nil
			and self._components.AnimationStateComponent ~= nil
			and self._components.AnimationLoopingComponent ~= nil
			and self._components.RoleComponent ~= nil
			and self._components.LifetimeComponent ~= nil
			and self._components.ModelRefComponent ~= nil
			and self._components.ActiveTag ~= nil
			and self._components.DirtyTag ~= nil,
		"UnitEntityFactory: missing UnitComponentRegistry components"
	)
	self:_ConfigureSpatialComponents("ModelRefComponent", "TransformComponent")
	self:RegisterBucketLookupIndex("OwnerKey")
	self:RegisterUniqueLookupIndex("UnitGuid")
end

function UnitEntityFactory:CreateUnit(unitGuid: string, request: SpawnUnitRequest, definition: UnitDefinition, now: number): number
	self:RequireReady()
	local entity = self:_CreateEntity()

	self:_Set(entity, self._components.IdentityComponent, {
		UnitGuid = unitGuid,
		UnitId = request.UnitId,
	} :: IdentityComponent)

	self:_Set(entity, self._components.OwnershipComponent, {
		Faction = request.Faction,
		OwnerKind = request.OwnerKind,
		OwnerId = request.OwnerId,
	} :: OwnershipComponent)

	self:_Set(entity, self._components.TransformComponent, {
		CFrame = request.SpawnCFrame,
	} :: TransformComponent)

	self:_Set(entity, self._components.HealthComponent, {
		Hp = definition.MaxHp,
		MaxHp = definition.MaxHp,
	} :: HealthComponent)

	self:_Set(entity, self._components.BaseMoveSpeedComponent, {
		Value = definition.MoveSpeed,
	} :: MoveSpeedComponent)
	self:_Set(entity, self._components.CurrentMoveSpeedComponent, {
		Value = definition.MoveSpeed,
	} :: MoveSpeedComponent)
	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = nil,
		IsMoving = false,
	} :: PathStateComponent)

	local animationState, isLooping = UnitRuntimeProfiles.ResolveAnimationState({
		VariantId = definition.RuntimeProfileId,
		CombatAction = nil,
	})
	self:_Set(entity, self._components.AnimationStateComponent, animationState :: AnimationStateComponent)
	self:_Set(entity, self._components.AnimationLoopingComponent, isLooping :: AnimationLoopingComponent)

	self:_Set(entity, self._components.RoleComponent, {
		Role = definition.Role,
		DisplayName = definition.DisplayName,
		MaxHp = definition.MaxHp,
	} :: RoleComponent)

	if request.Lifetime ~= nil then
		self:_Set(entity, self._components.LifetimeComponent, {
			SpawnedAt = now,
			ExpiresAt = now + request.Lifetime,
		} :: LifetimeComponent)
	end

	self:_Add(entity, self._components.ActiveTag)
	self:_Add(entity, self._components.DirtyTag)
	self:SetBucketLookup("OwnerKey", _ownerKey(request.OwnerKind, request.OwnerId), entity)
	self:SetUniqueLookup("UnitGuid", unitGuid, entity)

	return entity
end

function UnitEntityFactory:GetIdentity(entity: number): IdentityComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.IdentityComponent)
end

function UnitEntityFactory:GetOwnership(entity: number): OwnershipComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.OwnershipComponent)
end

function UnitEntityFactory:GetTransform(entity: number): TransformComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.TransformComponent)
end

function UnitEntityFactory:SetTransform(entity: number, cframe: CFrame)
	self:RequireReady()
	self:_Set(entity, self._components.TransformComponent, {
		CFrame = cframe,
	} :: TransformComponent)
	self:_Add(entity, self._components.DirtyTag)
end

function UnitEntityFactory:GetHealth(entity: number): HealthComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.HealthComponent)
end

function UnitEntityFactory:GetBaseMoveSpeed(entity: number): number?
	self:RequireReady()
	local moveSpeed = self:_Get(entity, self._components.BaseMoveSpeedComponent)
	return if moveSpeed ~= nil then moveSpeed.Value else nil
end

function UnitEntityFactory:GetCurrentMoveSpeed(entity: number): number?
	self:RequireReady()
	local moveSpeed = self:_Get(entity, self._components.CurrentMoveSpeedComponent)
	return if moveSpeed ~= nil then moveSpeed.Value else nil
end

function UnitEntityFactory:SetCurrentMoveSpeed(entity: number, speed: number)
	self:RequireReady()
	if type(speed) ~= "number" then
		return
	end

	local currentMoveSpeed = self:_Get(entity, self._components.CurrentMoveSpeedComponent)
	if currentMoveSpeed ~= nil and currentMoveSpeed.Value == speed then
		return
	end

	self:_Set(entity, self._components.CurrentMoveSpeedComponent, {
		Value = speed,
	} :: MoveSpeedComponent)
	self:_Add(entity, self._components.DirtyTag)
end

function UnitEntityFactory:GetAnimationState(entity: number): AnimationStateComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.AnimationStateComponent)
end

function UnitEntityFactory:GetAnimationLooping(entity: number): AnimationLoopingComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.AnimationLoopingComponent)
end

function UnitEntityFactory:GetRole(entity: number): RoleComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.RoleComponent)
end

function UnitEntityFactory:GetPathState(entity: number): PathStateComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.PathStateComponent)
end

function UnitEntityFactory:SetGoalPosition(entity: number, goalPosition: Vector3)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = goalPosition,
		IsMoving = false,
	} :: PathStateComponent)
	self:_Add(entity, self._components.DirtyTag)
end

function UnitEntityFactory:ClearGoalPosition(entity: number)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = nil,
		IsMoving = false,
	} :: PathStateComponent)
	self:_Add(entity, self._components.DirtyTag)
end

function UnitEntityFactory:SetPathMoving(entity: number, isMoving: boolean)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end
	if state.IsMoving == isMoving then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = state.GoalPosition,
		IsMoving = isMoving,
	} :: PathStateComponent)
	self:_Add(entity, self._components.DirtyTag)
end

function UnitEntityFactory:GetLifetime(entity: number): LifetimeComponent?
	self:RequireReady()
	if not self:_Exists(entity) then
		return nil
	end
	if not self:_Has(entity, self._components.LifetimeComponent) then
		return nil
	end
	return self:_Get(entity, self._components.LifetimeComponent)
end

function UnitEntityFactory:IsActive(entity: number): boolean
	self:RequireReady()
	return self:_Exists(entity) and self:_Has(entity, self._components.ActiveTag)
end

function UnitEntityFactory:QueryActiveEntities(): { number }
	self:RequireReady()
	return self:CollectQuery(self._components.ActiveTag)
end

function UnitEntityFactory:QueryOwnerEntities(ownerKind: string, ownerId: string): { number }
	self:RequireReady()
	return self:QueryBucketLookup("OwnerKey", _ownerKey(ownerKind, ownerId))
end

function UnitEntityFactory:GetEntityByUnitGuid(unitGuid: string): number?
	self:RequireReady()
	return self:FindEntityByUniqueLookup("UnitGuid", unitGuid)
end

function UnitEntityFactory:GetOwnerUnitCount(ownerKind: string, ownerId: string): number
	return self:GetBucketLookupCount("OwnerKey", _ownerKey(ownerKind, ownerId))
end

function UnitEntityFactory:DeleteEntity(entity: number?): boolean
	self:RequireReady()
	if entity == nil or not self:_Exists(entity) then
		return false
	end

	if self:_Has(entity, self._components.ActiveTag) then
		self:_Remove(entity, self._components.ActiveTag)
	end
	if self:_Has(entity, self._components.DirtyTag) then
		self:_Remove(entity, self._components.DirtyTag)
	end

	self:ClearBucketLookup("OwnerKey", entity)
	self:ClearUniqueLookup("UnitGuid", entity)
	self:MarkForDestruction(entity)
	return true
end

function UnitEntityFactory:DeleteOwnerUnits(ownerKind: string, ownerId: string): number
	local deletedCount = 0
	for _, entity in ipairs(self:QueryOwnerEntities(ownerKind, ownerId)) do
		if self:DeleteEntity(entity) then
			deletedCount += 1
		end
	end
	return deletedCount
end

function UnitEntityFactory:DeleteAll(): number
	local deletedCount = 0
	for _, entity in ipairs(self:QueryActiveEntities()) do
		if self:DeleteEntity(entity) then
			deletedCount += 1
		end
	end
	return deletedCount
end

function UnitEntityFactory:FlushPendingDeletes(): boolean
	self:RequireReady()
	return self:FlushDestructionQueue()
end

return UnitEntityFactory
