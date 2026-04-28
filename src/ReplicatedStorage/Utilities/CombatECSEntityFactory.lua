--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)

type TCombatAction = ExecutorTypes.TCombatActionComponent

local CombatECSEntityFactory = {}
CombatECSEntityFactory.__index = CombatECSEntityFactory
setmetatable(CombatECSEntityFactory, BaseECSEntityFactory)

function CombatECSEntityFactory.new(contextName: string)
	return setmetatable(BaseECSEntityFactory.new(contextName), CombatECSEntityFactory)
end

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

function CombatECSEntityFactory:SetBehaviorTree(entity: number, treeInstance: any, tickInterval: number)
	self:_Set(entity, self._components.BehaviorTreeComponent, {
		TreeInstance = treeInstance,
		TickInterval = tickInterval,
		LastTickTime = 0,
	})
end

function CombatECSEntityFactory:GetBehaviorTree(entity: number)
	return self:_Get(entity, self._components.BehaviorTreeComponent)
end

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

function CombatECSEntityFactory:GetCombatAction(entity: number)
	return self:_Get(entity, self._components.CombatActionComponent)
end

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

function CombatECSEntityFactory:ClearAction(entity: number)
	self:SetCombatAction(entity, self:BuildDefaultCombatAction())
end

function CombatECSEntityFactory:ResetActionState(entity: number)
	self:SetCombatAction(entity, self:BuildDefaultCombatAction())
end

function CombatECSEntityFactory:GetBehaviorConfig(entity: number)
	self:RequireReady()
	if self._components.BehaviorConfigComponent == nil then
		return nil
	end

	return self:_Get(entity, self._components.BehaviorConfigComponent)
end

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

function CombatECSEntityFactory:_MarkDirtyIfSupported(entity: number)
	local dirtyTag = self._components and self._components.DirtyTag or nil
	if dirtyTag ~= nil and self:_Exists(entity) then
		self:_Add(entity, dirtyTag)
	end
end

return CombatECSEntityFactory
