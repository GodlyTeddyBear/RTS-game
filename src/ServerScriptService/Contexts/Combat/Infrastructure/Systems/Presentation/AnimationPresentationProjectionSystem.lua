--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local AnimationPresentationProjectionSystem = {}
AnimationPresentationProjectionSystem.__index = AnimationPresentationProjectionSystem

local INACTIVE_STATUSES = table.freeze({
	Cancelled = true,
	Completed = true,
	Failed = true,
})

local ACTION_PRIORITY = table.freeze({
	"Extract",
	"Stasis",
	"BuildStructure",
})

function AnimationPresentationProjectionSystem.new(entityFactory: any, ruleRegistry: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_ruleRegistry = ruleRegistry,
	}, AnimationPresentationProjectionSystem)
end

function AnimationPresentationProjectionSystem:Run()
	-- READS: Combat.AttackState, Combat.StatusAuraState, Structure.ExtractState, Structure.BuildContributionState, Movement.ApplyResult, AI.ActionIntent, AI.ActionState
	-- WRITES: Animation.ActionChannels, configured target presentation, Entity.Target, Entity.DirtyTag
	for _, rule in ipairs(self._ruleRegistry:GetMovementPresentationRules()) do
		self:_RunRule(rule)
	end
end

function AnimationPresentationProjectionSystem:_RunRule(rule: any)
	if type(rule.Query) ~= "table" then
		return
	end

	local result = self._entityFactory:Query(rule.Query)
	if not result.success then
		return
	end

	for _, entity in ipairs(result.value) do
		self:_ProjectEntity(rule, entity)
	end
end

function AnimationPresentationProjectionSystem:_ProjectEntity(rule: any, entity: number)
	local applyResult = self:_Get(entity, "ApplyResult", "Movement")
	local actionIntent = self:_Get(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	local attackState = self:_Get(entity, "AttackState", "Combat")
	local isMoving = type(applyResult) == "table" and applyResult.IsMoving == true

	if self:_ShouldProjectAttack(rule, entity, attackState) and type(rule.Attack) == "table" then
		self:_ApplyAttackProjection(rule, entity, attackState)
		return
	end

	local actionId = self:_ResolveActionProjection(rule, entity, actionIntent, actionState, isMoving)
	if actionId ~= nil then
		self:_ApplyActionProjection(rule, entity, rule.ActionPresentation[actionId], self:_GetDomainState(entity, actionId))
		return
	end

	self:_ApplyFallbackProjection(rule, entity, isMoving)
end

function AnimationPresentationProjectionSystem:_ResolveActionProjection(
	rule: any,
	entity: number,
	actionIntent: any,
	actionState: any,
	isMoving: boolean
): string?
	if type(rule.ActionPresentation) ~= "table" then
		return nil
	end

	for _, actionId in ipairs(ACTION_PRIORITY) do
		local projection = rule.ActionPresentation[actionId]
		if
			type(projection) == "table"
			and self:_CanApplyActionProjection(projection, isMoving)
			and self:_IsActionActive(entity, actionId, actionIntent, actionState)
		then
			return actionId
		end
	end

	return nil
end

function AnimationPresentationProjectionSystem:_IsActionActive(
	entity: number,
	actionId: string,
	actionIntent: any,
	actionState: any
): boolean
	if type(actionIntent) == "table" and actionIntent.ActionId == actionId then
		return self:_HasActiveDomainState(entity, actionId)
	end

	if type(actionState) ~= "table" or actionState.ActionId ~= actionId or INACTIVE_STATUSES[actionState.Status] == true then
		return false
	end

	return self:_HasActiveDomainState(entity, actionId)
end

function AnimationPresentationProjectionSystem:_HasActiveDomainState(entity: number, actionId: string): boolean
	return self:_IsStateActive(self:_GetDomainState(entity, actionId), actionId)
end

function AnimationPresentationProjectionSystem:_GetDomainState(entity: number, actionId: string): any
	if actionId == "Extract" then
		return self:_Get(entity, "ExtractState", "Structure")
	end
	if actionId == "Stasis" then
		return self:_Get(entity, "StatusAuraState", "Combat")
	end
	if actionId == "BuildStructure" then
		return self:_Get(entity, "BuildContributionState", "Structure")
	end

	return nil
end

function AnimationPresentationProjectionSystem:_IsAttackActive(attackState: any): boolean
	if type(attackState) ~= "table" or attackState.ActionId ~= "Attack" then
		return false
	end
	return attackState.Phase ~= "Completed" and attackState.Phase ~= "Failed"
end

function AnimationPresentationProjectionSystem:_ShouldProjectAttack(rule: any, entity: number, attackState: any): boolean
	if type(attackState) ~= "table" or attackState.ActionId ~= "Attack" or attackState.Phase == "Failed" then
		return false
	end
	if self:_IsAttackActive(attackState) then
		return true
	end
	if attackState.Phase ~= "Completed" or attackState.HasEmittedRequest ~= true then
		return false
	end

	local attack = rule.Attack
	local animation = if type(attack) == "table" then attack.Animation else nil
	if type(animation) ~= "table" or type(animation.RevisionKey) ~= "string" then
		return false
	end

	local revision = self:_ResolveChannelRevision(attackState)
	if revision == nil then
		return false
	end

	local currentRevision = self:_GetCurrentChannelRevision(entity, animation)
	return currentRevision ~= revision
end

function AnimationPresentationProjectionSystem:_IsStateActive(state: any, expectedActionId: string): boolean
	if type(state) ~= "table" or state.ActionId ~= expectedActionId then
		return false
	end
	return INACTIVE_STATUSES[state.Status] ~= true
end

function AnimationPresentationProjectionSystem:_CanApplyActionProjection(actionProjection: any, isMoving: boolean): boolean
	return not (actionProjection.WhenNotMoving == true and isMoving)
end

function AnimationPresentationProjectionSystem:_ApplyAttackProjection(rule: any, entity: number, attackState: any)
	local attack = rule.Attack
	if type(attack.Target) == "table" then
		self._entityFactory:Set(entity, "Target", {
			TargetEntity = attackState.TargetEntity,
			TargetKind = attackState.TargetKind or attack.Target.TargetKind,
		}, "Entity")
	end
	if type(attack.Animation) == "table" then
		self:_SetAnimation(
			entity,
			attack.Animation,
			attack.Animation.State or "Attack",
			self:_ResolveChannelRevision(attackState)
		)
	end
	if type(attack.TargetEntityId) == "table" then
		self:_SetTargetEntityId(entity, attack.TargetEntityId, attackState.TargetEntity)
	elseif type(rule.TargetEntityId) == "table" then
		self:_SetTargetEntityId(entity, rule.TargetEntityId, attackState.TargetEntity)
	end
	self:_MarkDirty(entity, rule)
end

function AnimationPresentationProjectionSystem:_ApplyActionProjection(
	rule: any,
	entity: number,
	actionProjection: any,
	domainState: any
)
	if type(actionProjection.Animation) == "table" then
		self:_SetAnimation(
			entity,
			actionProjection.Animation,
			actionProjection.Animation.State or "Idle",
			self:_ResolveChannelRevision(domainState)
		)
	end
	if type(actionProjection.TargetEntityId) == "table" then
		self:_SetTargetEntityId(entity, actionProjection.TargetEntityId, actionProjection.TargetEntity)
	elseif type(rule.TargetEntityId) == "table" then
		self:_SetTargetEntityId(entity, rule.TargetEntityId, actionProjection.TargetEntity)
	end
	self:_MarkDirty(entity, rule)
end

function AnimationPresentationProjectionSystem:_ApplyFallbackProjection(rule: any, entity: number, isMoving: boolean)
	if type(rule.Animation) == "table" then
		if rule.Animation.ActionOnly == true then
			self:_SetAnimation(entity, rule.Animation, "", nil)
		else
			self:_SetAnimation(
				entity,
				rule.Animation,
				if isMoving then rule.Animation.MovingState or "Walk" else rule.Animation.IdleState or "Idle",
				nil
			)
		end
	elseif type(rule.ActionPresentation) == "table" and type(rule.ActionPresentation.Idle) == "table" then
		self:_ApplyActionProjection(rule, entity, rule.ActionPresentation.Idle, nil)
		return
	end

	if type(rule.TargetEntityId) == "table" then
		self:_SetTargetEntityId(entity, rule.TargetEntityId, nil)
	end
	self:_MarkDirty(entity, rule)
end

function AnimationPresentationProjectionSystem:_SetAnimation(
	entity: number,
	animation: any,
	state: string,
	revision: number?
)
	local channelId = if type(animation.ChannelId) == "string" and animation.ChannelId ~= "" then animation.ChannelId else "FullBody"
	local currentChannels = self:_Get(entity, "ActionChannels", "Animation")
	local nextChannels = if type(currentChannels) == "table" then table.clone(currentChannels) else {}

	if type(state) ~= "string" or state == "" or state == "Idle" or state == "Walk" then
		nextChannels[channelId] = nil
	else
		local resolvedRevision = revision or self:_GetCurrentChannelRevision(entity, animation) or 0
		nextChannels[channelId] = {
			ActionId = state,
			Revision = resolvedRevision,
			StartedAt = Workspace:GetServerTimeNow(),
			PlaybackSpeed = if type(animation.PlaybackSpeed) == "number" then animation.PlaybackSpeed else 1,
		}
	end

	self._entityFactory:Set(entity, "ActionChannels", nextChannels, "Animation")
end

function AnimationPresentationProjectionSystem:_GetCurrentChannelRevision(entity: number, animation: any): number?
	local channelId = if type(animation.ChannelId) == "string" and animation.ChannelId ~= "" then animation.ChannelId else "FullBody"
	local channels = self:_Get(entity, "ActionChannels", "Animation")
	local channel = if type(channels) == "table" then channels[channelId] else nil
	if type(channel) == "table" and type(channel.Revision) == "number" then
		return channel.Revision
	end
	return nil
end

function AnimationPresentationProjectionSystem:_ResolveChannelRevision(state: any): number?
	if type(state) ~= "table" then
		return nil
	end
	if type(state.RequestedAt) == "number" then
		return state.RequestedAt
	end
	if type(state.StartedAt) == "number" then
		return state.StartedAt
	end
	if type(state.UpdatedAt) == "number" then
		return state.UpdatedAt
	end
	return nil
end

function AnimationPresentationProjectionSystem:_SetTargetEntityId(entity: number, targetConfig: any, targetEntity: any)
	local identity = if type(targetEntity) == "number" then self:_Get(targetEntity, "Identity", "Entity") else nil
	local entityId = if type(identity) == "table" and type(identity.EntityId) == "string" then identity.EntityId else nil
	self._entityFactory:Set(entity, targetConfig.Key, entityId, targetConfig.FeatureName)
end

function AnimationPresentationProjectionSystem:_MarkDirty(entity: number, rule: any)
	if rule.MarkDirty ~= false then
		self._entityFactory:Add(entity, "DirtyTag", "Entity")
	end
end

function AnimationPresentationProjectionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return AnimationPresentationProjectionSystem
