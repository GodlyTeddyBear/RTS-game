--!strict

--[=[
    @class UnitEntityFactory
    Owns authoritative unit ECS entities, indexed lookup helpers, and unit-specific component mutations.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CombatECSEntityFactory = require(ServerStorage.Utilities.ECSUtilities.CombatECSEntityFactory)
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
type CombatActionComponent = UnitTypes.CombatActionComponent
type AttackCooldownComponent = UnitTypes.AttackCooldownComponent
type BehaviorConfigComponent = UnitTypes.BehaviorConfigComponent
type TargetComponent = UnitTypes.TargetComponent
type LockOnComponent = UnitTypes.LockOnComponent
type RoleComponent = UnitTypes.RoleComponent
type BuilderAssignmentComponent = UnitTypes.BuilderAssignmentComponent
type PathStateComponent = UnitTypes.PathStateComponent
type LifetimeComponent = UnitTypes.LifetimeComponent

local UnitEntityFactory = {}
UnitEntityFactory.__index = UnitEntityFactory
setmetatable(UnitEntityFactory, { __index = CombatECSEntityFactory })

local function _ownerKey(ownerKind: string, ownerId: string): string
	return ownerKind .. ":" .. ownerId
end

-- Creates the unit entity factory with the unit namespace and no instantiated entities yet.
function UnitEntityFactory.new()
	return setmetatable(CombatECSEntityFactory.new("Unit"), UnitEntityFactory)
end

-- Binds the unit component registry used to create and mutate unit entities.
function UnitEntityFactory:_GetComponentRegistryName(): string
	return "UnitComponentRegistry"
end

-- Verifies the component registry before wiring the spatial indexes and lookup buckets the unit context depends on.
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
			and self._components.BuilderAssignmentComponent ~= nil
			and self._components.LifetimeComponent ~= nil
			and self._components.ModelRefComponent ~= nil
			and self._components.BehaviorTreeComponent ~= nil
			and self._components.CombatActionComponent ~= nil
			and self._components.AttackCooldownComponent ~= nil
			and self._components.BehaviorConfigComponent ~= nil
			and self._components.TargetComponent ~= nil
			and self._components.LockOnComponent ~= nil
			and self._components.ActiveTag ~= nil
			and self._components.DirtyTag ~= nil
			and self._components.GoalReachedTag ~= nil,
		"UnitEntityFactory: missing UnitComponentRegistry components"
	)
	self:_ConfigureSpatialComponents("ModelRefComponent", "TransformComponent")
	self:RegisterBucketLookupIndex("OwnerKey")
	self:RegisterUniqueLookupIndex("UnitGuid")
end

-- Creates a new authoritative unit entity and seeds every ECS component that describes the unit.
function UnitEntityFactory:CreateUnit(unitGuid: string, request: SpawnUnitRequest, definition: UnitDefinition, now: number): number
	self:RequireReady()
	local entity = self:_CreateEntity()

	-- Seed identity and ownership first so lookup indexes can resolve the entity immediately.
	self:_Set(entity, self._components.IdentityComponent, {
		UnitGuid = unitGuid,
		UnitId = request.UnitId,
	} :: IdentityComponent)

	self:_Set(entity, self._components.OwnershipComponent, {
		Faction = request.Faction,
		OwnerKind = request.OwnerKind,
		OwnerId = request.OwnerId,
	} :: OwnershipComponent)

	-- Apply the initial transform, health, movement, animation, and role state from the spawn definition.
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
	local runtimeProfile = UnitRuntimeProfiles.GetByVariant(definition.RuntimeProfileId)
	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = nil,
		RequestedGoalPosition = nil,
		GoalRevision = 0,
		FailedGoalRevision = nil,
		IsMoving = false,
	} :: PathStateComponent)
	self:_Set(entity, self._components.CombatActionComponent, self:BuildDefaultCombatAction() :: CombatActionComponent)
	self:_Set(entity, self._components.AttackCooldownComponent, {
		Cooldown = 0,
		LastAttackTime = 0,
	} :: AttackCooldownComponent)
	self:_Set(entity, self._components.BehaviorConfigComponent, {
		TickInterval = runtimeProfile.TickInterval,
	} :: BehaviorConfigComponent)
	self:_Set(entity, self._components.TargetComponent, {
		TargetEntity = nil,
		TargetKind = "Enemy",
	} :: TargetComponent)
	self:_Set(entity, self._components.LockOnComponent, {
		Attachment0 = nil,
		Attachment1 = nil,
		Constraint = nil,
	} :: LockOnComponent)

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
	self:_Set(entity, self._components.BuilderAssignmentComponent, {
		TargetStructureEntity = nil,
	} :: BuilderAssignmentComponent)

	if request.Lifetime ~= nil then
		self:_Set(entity, self._components.LifetimeComponent, {
			SpawnedAt = now,
			ExpiresAt = now + request.Lifetime,
		} :: LifetimeComponent)
	end

	-- Mark the entity active and dirty so sync and replication can discover it on the next flush.
	self:_Add(entity, self._components.ActiveTag)
	self:_Add(entity, self._components.DirtyTag)
	self:SetBucketLookup("OwnerKey", _ownerKey(request.OwnerKind, request.OwnerId), entity)
	self:SetUniqueLookup("UnitGuid", unitGuid, entity)

	return entity
end

-- Stores the spawned model reference and marks the entity dirty so the model sync path can pick it up.
function UnitEntityFactory:SetModelRef(entity: number, model: Model)
	CombatECSEntityFactory.SetModelRef(self, entity, model)
	self:_Add(entity, self._components.DirtyTag)
end

-- Returns the model reference bound to the entity, if one has been assigned.
function UnitEntityFactory:GetModelRef(entity: number): { Model: Model }?
	self:RequireReady()
	return CombatECSEntityFactory.GetModelRef(self, entity)
end

-- Returns the identity component for the entity so other systems can read unit metadata.
function UnitEntityFactory:GetIdentity(entity: number): IdentityComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.IdentityComponent)
end

-- Returns the ownership component for the entity so cleanup and move-order logic can validate ownership.
function UnitEntityFactory:GetOwnership(entity: number): OwnershipComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.OwnershipComponent)
end

-- Returns the current derived transform snapshot for the entity.
function UnitEntityFactory:GetTransform(entity: number): TransformComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.TransformComponent)
end

-- Updates the derived transform snapshot from the live model position.
function UnitEntityFactory:UpdatePosition(entity: number, cframe: CFrame)
	self:RequireReady()
	self:SetTransformCFrame(entity, cframe)
	self:_Add(entity, self._components.DirtyTag)
end

-- Returns the health component so combat and sync systems can read current health values.
function UnitEntityFactory:GetHealth(entity: number): HealthComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.HealthComponent)
end

-- Returns the combat cooldown component used by future unit attack executors.
function UnitEntityFactory:GetAttackCooldown(entity: number): AttackCooldownComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.AttackCooldownComponent)
end

-- Updates the last attack timestamp while preserving the configured cooldown.
function UnitEntityFactory:SetLastAttackTime(entity: number, lastAttackTime: number)
	self:RequireReady()
	local attackCooldown = self:GetAttackCooldown(entity)
	if attackCooldown == nil then
		return
	end

	self:_Set(entity, self._components.AttackCooldownComponent, {
		Cooldown = attackCooldown.Cooldown,
		LastAttackTime = lastAttackTime,
	} :: AttackCooldownComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Returns the configured base move speed for the entity.
function UnitEntityFactory:GetBaseMoveSpeed(entity: number): number?
	self:RequireReady()
	local moveSpeed = self:_Get(entity, self._components.BaseMoveSpeedComponent)
	return if moveSpeed ~= nil then moveSpeed.Value else nil
end

-- Returns the current move speed after temporary modifiers have been applied.
function UnitEntityFactory:GetCurrentMoveSpeed(entity: number): number?
	self:RequireReady()
	local moveSpeed = self:_Get(entity, self._components.CurrentMoveSpeedComponent)
	return if moveSpeed ~= nil then moveSpeed.Value else nil
end

-- Updates the current move speed only when it changes so the dirty tag is not churned unnecessarily.
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

-- Returns the animation state component for replication and client animation playback.
function UnitEntityFactory:GetAnimationState(entity: number): AnimationStateComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.AnimationStateComponent)
end

-- Returns the animation looping state for replication and client animation playback.
function UnitEntityFactory:GetAnimationLooping(entity: number): AnimationLoopingComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.AnimationLoopingComponent)
end

-- Updates animation presentation only when the requested state differs from the current one.
function UnitEntityFactory:SetAnimationPresentation(entity: number, animationState: string, isLooping: boolean)
	self:RequireReady()

	local currentAnimationState = self:GetAnimationState(entity)
	local currentLooping = self:GetAnimationLooping(entity)
	if currentAnimationState == animationState and currentLooping == isLooping then
		return
	end

	self:_Set(entity, self._components.AnimationStateComponent, animationState)
	self:_Set(entity, self._components.AnimationLoopingComponent, isLooping)
	self:_Add(entity, self._components.DirtyTag)
end

-- Returns the role component used by gameplay and sync logic.
function UnitEntityFactory:GetRole(entity: number): RoleComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.RoleComponent)
end

-- Returns the current builder-assigned structure entity, if any.
function UnitEntityFactory:GetBuilderAssignment(entity: number): BuilderAssignmentComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.BuilderAssignmentComponent)
end

-- Assigns one builder to a specific structure entity.
function UnitEntityFactory:SetBuilderAssignment(entity: number, targetStructureEntity: number?)
	self:RequireReady()
	local currentAssignment = self:GetBuilderAssignment(entity)
	if currentAssignment ~= nil and currentAssignment.TargetStructureEntity == targetStructureEntity then
		return
	end

	self:_Set(entity, self._components.BuilderAssignmentComponent, {
		TargetStructureEntity = targetStructureEntity,
	} :: BuilderAssignmentComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Clears any current builder assignment.
function UnitEntityFactory:ClearBuilderAssignment(entity: number)
	self:SetBuilderAssignment(entity, nil)
end

-- Marks the unit as having reached its goal and removes it from the active query.
function UnitEntityFactory:MarkGoalReached(entity: number)
	self:RequireReady()
	self:_Remove(entity, self._components.ActiveTag)
	self:_Add(entity, self._components.GoalReachedTag)
	self:_Add(entity, self._components.DirtyTag)
end

-- Restores the active tag and clears the goal-reached marker.
function UnitEntityFactory:ClearGoalReached(entity: number)
	self:RequireReady()
	self:_Remove(entity, self._components.GoalReachedTag)
	self:_Add(entity, self._components.ActiveTag)
	self:_Add(entity, self._components.DirtyTag)
end

-- Marks the entity dirty so the sync layer re-emits it on the next pass.
function UnitEntityFactory:MarkDirty(entity: number)
	self:RequireReady()
	self:_Add(entity, self._components.DirtyTag)
end

-- Reports whether the entity currently carries the dirty tag.
function UnitEntityFactory:IsDirty(entity: number): boolean
	self:RequireReady()
	return self:_Has(entity, self._components.DirtyTag)
end

-- Returns the path state used by movement and behavior systems.
function UnitEntityFactory:GetPathState(entity: number): PathStateComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.PathStateComponent)
end

-- Returns the current target payload used by future combat-capable unit behaviors.
function UnitEntityFactory:GetTarget(entity: number): TargetComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.TargetComponent)
end

-- Updates the target payload for one unit entity.
function UnitEntityFactory:SetTarget(entity: number, targetEntity: number?, targetKind: "Enemy" | "Structure" | "Base")
	self:RequireReady()
	self:_Set(entity, self._components.TargetComponent, {
		TargetEntity = targetEntity,
		TargetKind = targetKind,
	} :: TargetComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Clears the current unit target, defaulting back to enemy-facing target kind.
function UnitEntityFactory:ClearTarget(entity: number)
	self:RequireReady()
	self:_Set(entity, self._components.TargetComponent, {
		TargetEntity = nil,
		TargetKind = "Enemy",
	} :: TargetComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Returns the current lock-on constraint payload, if any.
function UnitEntityFactory:GetLockOn(entity: number): LockOnComponent?
	self:RequireReady()
	return self:_Get(entity, self._components.LockOnComponent)
end

-- Stores lock-on attachments and constraint refs for one unit.
function UnitEntityFactory:SetLockOn(
	entity: number,
	lockOn: {
		Attachment0: Attachment?,
		Attachment1: Attachment?,
		Constraint: AlignOrientation?,
	}
)
	self:RequireReady()
	self:_Set(entity, self._components.LockOnComponent, {
		Attachment0 = lockOn.Attachment0,
		Attachment1 = lockOn.Attachment1,
		Constraint = lockOn.Constraint,
	} :: LockOnComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Clears lock-on refs for one unit.
function UnitEntityFactory:ClearLockOn(entity: number)
	self:RequireReady()
	self:_Set(entity, self._components.LockOnComponent, {
		Attachment0 = nil,
		Attachment1 = nil,
		Constraint = nil,
	} :: LockOnComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Returns whether the unit still has a goal that should be retried by the behavior runtime.
function UnitEntityFactory:HasActionableGoal(entity: number): boolean
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil or state.GoalPosition == nil then
		return false
	end

	return state.FailedGoalRevision ~= state.GoalRevision
end

-- Sets a new goal position and resets movement state so the behavior system can take over.
function UnitEntityFactory:SetGoalPosition(entity: number, goalPosition: Vector3, requestedGoalPosition: Vector3?)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = goalPosition,
		RequestedGoalPosition = if requestedGoalPosition ~= nil then requestedGoalPosition else goalPosition,
		GoalRevision = state.GoalRevision + 1,
		FailedGoalRevision = nil,
		IsMoving = false,
	} :: PathStateComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Clears the movement goal while preserving the entity's other state.
function UnitEntityFactory:ClearGoalPosition(entity: number)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = nil,
		RequestedGoalPosition = nil,
		GoalRevision = state.GoalRevision,
		FailedGoalRevision = nil,
		IsMoving = false,
	} :: PathStateComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Marks the current goal revision as failed so the behavior tree stops auto-retrying it.
function UnitEntityFactory:MarkGoalFailedCurrentRevision(entity: number)
	self:RequireReady()
	local state = self:GetPathState(entity)
	if state == nil or state.GoalPosition == nil then
		return
	end
	if state.FailedGoalRevision == state.GoalRevision then
		return
	end

	self:_Set(entity, self._components.PathStateComponent, {
		GoalPosition = state.GoalPosition,
		RequestedGoalPosition = state.RequestedGoalPosition,
		GoalRevision = state.GoalRevision,
		FailedGoalRevision = state.GoalRevision,
		IsMoving = false,
	} :: PathStateComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Updates whether the movement system is actively advancing the unit.
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
		RequestedGoalPosition = state.RequestedGoalPosition,
		GoalRevision = state.GoalRevision,
		FailedGoalRevision = state.FailedGoalRevision,
		IsMoving = isMoving,
	} :: PathStateComponent)
	self:_Add(entity, self._components.DirtyTag)
end

-- Returns the lifetime component when the unit was spawned with a finite lifetime.
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

-- Reports whether the entity is still active and available for gameplay systems.
function UnitEntityFactory:IsActive(entity: number): boolean
	self:RequireReady()
	return self:_Exists(entity) and self:_Has(entity, self._components.ActiveTag)
end

-- Returns the current derived transform snapshot through the same name Enemy uses.
function UnitEntityFactory:GetPosition(entity: number): TransformComponent?
	return self:GetTransform(entity)
end

-- Returns the current world cframe used for death/cleanup projection paths.
function UnitEntityFactory:GetDeathCFrame(entity: number): CFrame?
	return self:GetEntityCFrame(entity)
end

-- Returns every active unit entity tracked by the unit ECS world.
function UnitEntityFactory:QueryActiveEntities(): { number }
	self:RequireReady()
	return self:CollectQuery(self._components.ActiveTag)
end

-- Returns every goal-reached unit entity tracked by the unit ECS world.
function UnitEntityFactory:QueryGoalReachedEntities(): { number }
	self:RequireReady()
	return self:CollectQuery(self._components.GoalReachedTag)
end

-- Returns every unit entity owned by the requested owner bucket.
function UnitEntityFactory:QueryOwnerEntities(ownerKind: string, ownerId: string): { number }
	self:RequireReady()
	return self:QueryBucketLookup("OwnerKey", _ownerKey(ownerKind, ownerId))
end

-- Finds the entity that owns the requested unit GUID, if one exists.
function UnitEntityFactory:GetEntityByUnitGuid(unitGuid: string): number?
	self:RequireReady()
	return self:FindEntityByUniqueLookup("UnitGuid", unitGuid)
end

-- Returns the number of active units in the requested owner bucket.
function UnitEntityFactory:GetOwnerUnitCount(ownerKind: string, ownerId: string): number
	return self:GetBucketLookupCount("OwnerKey", _ownerKey(ownerKind, ownerId))
end

-- Removes the entity's active and dirty tags and schedules the entity for destruction.
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

-- Deletes every entity in the requested owner bucket.
function UnitEntityFactory:DeleteOwnerUnits(ownerKind: string, ownerId: string): number
	local deletedCount = 0
	for _, entity in ipairs(self:QueryOwnerEntities(ownerKind, ownerId)) do
		if self:DeleteEntity(entity) then
			deletedCount += 1
		end
	end
	return deletedCount
end

-- Deletes every active unit entity regardless of owner.
function UnitEntityFactory:DeleteAll(): number
	local deletedCount = 0
	for _, entity in ipairs(self:QueryActiveEntities()) do
		if self:DeleteEntity(entity) then
			deletedCount += 1
		end
	end
	return deletedCount
end

-- Flushes any queued entity destructions after a cleanup pass.
function UnitEntityFactory:FlushPendingDeletes(): boolean
	self:RequireReady()
	return self:FlushDestructionQueue()
end

return UnitEntityFactory
