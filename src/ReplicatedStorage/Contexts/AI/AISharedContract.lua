--!strict

export type TAIEntityProfile = {
	DefinitionId: string,
	TickInterval: number,
	InitialBehaviorId: string?,
	InitialNodePath: { string }?,
	Blackboard: any?,
	ActionStateStatus: string?,
}

export type TAIEntityEvaluationOptions = {
	Force: boolean?,
	DeltaTime: number?,
	Facts: any?,
	Now: number?,
}

export type TAIEntityEvaluationResult = {
	Evaluated: boolean,
	SkippedReason: string?,
	DefinitionId: string?,
	ActionIntent: any?,
	BehaviorId: string?,
}

export type TAIFactProviderContext = {
	Entity: number,
	EntityContext: any,
	Now: number,
	BehaviorTree: any,
	CurrentBehavior: any,
	BehaviorState: any,
	ActionState: any,
}

export type TAIFactProviderPayload = {
	ProviderId: string,
	BuildFacts: (context: TAIFactProviderContext) -> any,
	Metadata: any?,
}

export type TAIActionStartComponent = {
	FeatureName: string,
	Key: string,
}

export type TAIActionStartContext = {
	Entity: number,
	EntityContext: any,
	ActionIntent: any,
	ActionState: any,
	Now: number,
}

local AISharedContract = {}

AISharedContract.FeatureName = "AI"

AISharedContract.Components = table.freeze({
	BehaviorTree = "BehaviorTree",
	CurrentBehavior = "CurrentBehavior",
	DesiredBehavior = "DesiredBehavior",
	BehaviorState = "BehaviorState",
	ActionIntent = "ActionIntent",
	ActionState = "ActionState",
})

AISharedContract.Tags = table.freeze({
	BehaviorDirtyTag = "BehaviorDirtyTag",
	ActionIntentTag = "ActionIntentTag",
	ActionDirtyTag = "ActionDirtyTag",
})

AISharedContract.BehaviorStatus = table.freeze({
	Idle = "Idle",
	Active = "Active",
	Completed = "Completed",
	Failed = "Failed",
})

AISharedContract.ActionStatus = table.freeze({
	Idle = "Idle",
	Requested = "Requested",
	Running = "Running",
	Completed = "Completed",
	Cancelled = "Cancelled",
	Failed = "Failed",
})

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = deepClone(nestedValue)
	end
	return clone
end

local function cloneNodePath(nodePath: { string }?): { string }
	local clone = {}
	if type(nodePath) ~= "table" then
		return clone
	end

	for _, nodeId in ipairs(nodePath) do
		if type(nodeId) == "string" then
			table.insert(clone, nodeId)
		end
	end
	return clone
end

function AISharedContract.IsBehaviorStatus(status: any): boolean
	for _, value in pairs(AISharedContract.BehaviorStatus) do
		if status == value then
			return true
		end
	end
	return false
end

function AISharedContract.IsActionStatus(status: any): boolean
	for _, value in pairs(AISharedContract.ActionStatus) do
		if status == value then
			return true
		end
	end
	return false
end

function AISharedContract.BuildBehaviorTree(profile: TAIEntityProfile): any
	return {
		DefinitionId = profile.DefinitionId,
		TickInterval = profile.TickInterval,
	}
end

function AISharedContract.BuildCurrentBehavior(profile: TAIEntityProfile, timestamp: number?): any
	local behaviorId = profile.InitialBehaviorId
	local hasBehavior = type(behaviorId) == "string" and behaviorId ~= ""

	return {
		BehaviorId = if hasBehavior then behaviorId else nil,
		NodePath = cloneNodePath(profile.InitialNodePath),
		Status = if hasBehavior then AISharedContract.BehaviorStatus.Active else AISharedContract.BehaviorStatus.Idle,
		EnteredAt = if hasBehavior then (timestamp or os.clock()) else nil,
		LastEvaluatedAt = nil,
	}
end

function AISharedContract.BuildDesiredBehavior(profile: TAIEntityProfile): any
	return {
		BehaviorId = profile.InitialBehaviorId,
		NodePath = cloneNodePath(profile.InitialNodePath),
		Reason = nil,
		RequestedAt = nil,
	}
end

function AISharedContract.BuildBehaviorState(profile: TAIEntityProfile): any
	return {
		Blackboard = deepClone(profile.Blackboard or {}),
		TransitionCount = 0,
	}
end

function AISharedContract.BuildActionIntent(entity: number, actionId: string, targetEntity: number?, data: any?): any
	return {
		ActionId = actionId,
		SourceEntity = entity,
		TargetEntity = targetEntity,
		Data = deepClone(data),
		RequestedAt = os.clock(),
	}
end

function AISharedContract.BuildActionState(profile: TAIEntityProfile?): any
	local status = if profile ~= nil and AISharedContract.IsActionStatus(profile.ActionStateStatus)
		then profile.ActionStateStatus
		else AISharedContract.ActionStatus.Idle

	return {
		ActionId = nil,
		Status = status,
		StartedAt = nil,
		UpdatedAt = nil,
		ErrorCode = nil,
	}
end

return table.freeze(AISharedContract)
