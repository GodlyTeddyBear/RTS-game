--!strict

--[=[
	@class CombatECSEntityFactory
	Extends the base ECS entity factory with combat-specific action state and
	behavior-tree timing helpers for one combat context.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)

type TCombatAction = ExecutorTypes.TCombatActionComponent

local CombatECSEntityFactory = {}
CombatECSEntityFactory.__index = CombatECSEntityFactory
setmetatable(CombatECSEntityFactory, BaseECSEntityFactory)

-- Public

--[=[
	Creates a new combat entity factory for the supplied context name.
	@within CombatECSEntityFactory
	@param contextName string -- Owning context label used in assertions and diagnostics.
	@return CombatECSEntityFactory -- New combat factory instance.
]=]
function CombatECSEntityFactory.new(contextName: string)
	return setmetatable(BaseECSEntityFactory.new(contextName), CombatECSEntityFactory)
end

--[=[
	Builds the default combat action payload for a fresh or reset entity.
	@within CombatECSEntityFactory
	@return TCombatAction -- Idle combat action state.
]=]
function CombatECSEntityFactory:BuildDefaultCombatAction(): TCombatAction
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
	Sets the entity's behavior tree reference and resets its tick timer.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
	@param treeInstance any -- Behavior tree object assigned to the entity.
	@param tickInterval number -- Minimum time between behavior-tree evaluations.
]=]
function CombatECSEntityFactory:SetBehaviorTree(entity: number, treeInstance: any, tickInterval: number)
	self:_Set(entity, self._components.BehaviorTreeComponent, {
		TreeInstance = treeInstance,
		TickInterval = tickInterval,
		LastTickTime = 0,
	})
end

--[=[
	Returns the entity's behavior tree component, if one exists.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return any? -- Stored behavior-tree payload or nil.
]=]
function CombatECSEntityFactory:GetBehaviorTree(entity: number)
	return self:_Get(entity, self._components.BehaviorTreeComponent)
end

--[=[
	Updates only the last behavior-tree tick timestamp when a tree is present.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
	@param currentTime number -- Timestamp of the latest behavior-tree evaluation.
]=]
function CombatECSEntityFactory:UpdateBTLastTickTime(entity: number, currentTime: number)
	local behaviorTree = self:GetBehaviorTree(entity)
	if behaviorTree == nil then
		return
	end

	self:_Set(entity, self._components.BehaviorTreeComponent, {
		TreeInstance = behaviorTree.TreeInstance,
		TickInterval = behaviorTree.TickInterval,
		LastTickTime = currentTime,
	})
end

--[=[
	Returns the entity's current combat action component, if one exists.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return TCombatAction? -- Stored combat action or nil.
]=]
function CombatECSEntityFactory:GetCombatAction(entity: number)
	return self:_Get(entity, self._components.CombatActionComponent)
end

--[=[
	Replaces the combat action and marks the entity dirty when supported.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
	@param action TCombatAction -- Full combat action payload to store.
]=]
function CombatECSEntityFactory:SetCombatAction(entity: number, action: TCombatAction)
	self:_Set(entity, self._components.CombatActionComponent, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = action.PendingActionId,
		PendingActionData = action.PendingActionData,
		StartedAt = action.StartedAt,
		FinishedAt = action.FinishedAt,
	})
	self:_MarkDirtyIfSupported(entity)
end

--[=[
	Promotes the current action from running to committed once resolution begins.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
]=]
function CombatECSEntityFactory:PromoteToCommitted(entity: number)
	local action = self:GetCombatAction(entity)
	if action == nil or action.CurrentActionId == nil then
		return
	end

	if action.ActionState == "Committed" then
		return
	end

	self:SetCombatAction(entity, {
		CurrentActionId = action.CurrentActionId,
		ActionState = "Committed",
		ActionData = action.ActionData,
		PendingActionId = action.PendingActionId,
		PendingActionData = action.PendingActionData,
		StartedAt = action.StartedAt,
		FinishedAt = action.FinishedAt,
	})
end

--[=[
	Queues a pending combat action without disturbing the active action state.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
	@param actionId string -- Pending action identifier.
	@param actionData any? -- Pending action payload.
]=]
function CombatECSEntityFactory:SetPendingAction(entity: number, actionId: string, actionData: any?)
	local action = self:GetCombatAction(entity) or self:BuildDefaultCombatAction()
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

--[=[
	Clears any queued pending combat action while preserving the active action.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
]=]
function CombatECSEntityFactory:ClearPendingAction(entity: number)
	local action = self:GetCombatAction(entity) or self:BuildDefaultCombatAction()
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

--[=[
	Starts a new active combat action and clears any pending action.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
	@param actionId string -- Active action identifier.
	@param actionData any? -- Active action payload.
	@param currentTime number -- Timestamp when the action starts.
]=]
function CombatECSEntityFactory:StartAction(entity: number, actionId: string, actionData: any?, currentTime: number)
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

--[=[
	Resets the combat action to its default idle state.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
]=]
function CombatECSEntityFactory:ClearAction(entity: number)
	self:SetCombatAction(entity, self:BuildDefaultCombatAction())
end

--[=[
	Alias for `ClearAction` kept for older call sites.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
]=]
function CombatECSEntityFactory:ResetActionState(entity: number)
	self:SetCombatAction(entity, self:BuildDefaultCombatAction())
end

--[=[
	Returns the behavior config component when the context defines one.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to inspect.
	@return { TickInterval: number }? -- Stored behavior config or nil.
]=]
function CombatECSEntityFactory:GetBehaviorConfig(entity: number)
	self:RequireReady()
	if self._components.BehaviorConfigComponent == nil then
		return nil
	end

	return self:_Get(entity, self._components.BehaviorConfigComponent)
end

--[=[
	Updates the behavior config tick interval and keeps the behavior tree in sync.
	@within CombatECSEntityFactory
	@param entity number -- Entity id to update.
	@param config { TickInterval: number } -- Updated behavior tick interval payload.
]=]
function CombatECSEntityFactory:SetBehaviorConfig(entity: number, config: { TickInterval: number })
	self:RequireReady()
	if self._components.BehaviorConfigComponent == nil then
		return
	end

	self:_Set(entity, self._components.BehaviorConfigComponent, {
		TickInterval = config.TickInterval,
	})

	local behaviorTree = self:GetBehaviorTree(entity)
	if behaviorTree ~= nil then
		self:_Set(entity, self._components.BehaviorTreeComponent, {
			TreeInstance = behaviorTree.TreeInstance,
			TickInterval = config.TickInterval,
			LastTickTime = behaviorTree.LastTickTime,
		})
	end
end

-- Private

function CombatECSEntityFactory:_MarkDirtyIfSupported(entity: number)
	local dirtyTag = self._components and self._components.DirtyTag or nil
	if dirtyTag ~= nil and self:_Exists(entity) then
		self:_Add(entity, dirtyTag)
	end
end

return CombatECSEntityFactory
