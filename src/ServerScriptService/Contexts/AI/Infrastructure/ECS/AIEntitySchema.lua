--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local AIEntitySchema = {
	FeatureName = AISharedContract.FeatureName,
	Components = {
		[AISharedContract.Components.BehaviorTree] = {
			ECSName = "AI.BehaviorTree",
			Authority = "AUTHORITATIVE",
			Default = {
				DefinitionId = "",
				TickInterval = 0,
			},
		},
		[AISharedContract.Components.CurrentBehavior] = {
			ECSName = "AI.CurrentBehavior",
			Authority = "AUTHORITATIVE",
			Default = {
				BehaviorId = nil,
				NodePath = {},
				Status = AISharedContract.BehaviorStatus.Idle,
				EnteredAt = nil,
				LastEvaluatedAt = nil,
			},
		},
		[AISharedContract.Components.DesiredBehavior] = {
			ECSName = "AI.DesiredBehavior",
			Authority = "AUTHORITATIVE",
			Default = {
				BehaviorId = nil,
				NodePath = {},
				Reason = nil,
				RequestedAt = nil,
			},
		},
		[AISharedContract.Components.BehaviorState] = {
			ECSName = "AI.BehaviorState",
			Authority = "AUTHORITATIVE",
			Default = {
				Blackboard = {},
				TransitionCount = 0,
			},
		},
		[AISharedContract.Components.ActionIntent] = {
			ECSName = "AI.ActionIntent",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "",
				SourceEntity = 0,
				TargetEntity = nil,
				Data = nil,
				RequestedAt = 0,
			},
		},
		[AISharedContract.Components.ActionState] = {
			ECSName = "AI.ActionState",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = nil,
				Status = AISharedContract.ActionStatus.Idle,
				StartedAt = nil,
				UpdatedAt = nil,
				ErrorCode = nil,
			},
		},
	},
	Tags = {
		[AISharedContract.Tags.BehaviorDirtyTag] = {},
		[AISharedContract.Tags.ActionIntentTag] = {},
		[AISharedContract.Tags.ActionDirtyTag] = {},
	},
	Archetypes = {},
}

return table.freeze(AIEntitySchema)
