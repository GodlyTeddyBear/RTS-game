--!strict

local MovementEntitySchema = {
	FeatureName = "Movement",
	Components = {
		ActorProfile = {
			ECSName = "Movement.ActorProfile",
			Authority = "AUTHORITATIVE",
			Default = {
				ApplyMode = "Humanoid",
				DefaultMode = "Path",
				GoalReachedDistance = 4,
				AgentParams = nil,
			},
		},
		SpeedState = {
			ECSName = "Movement.SpeedState",
			Authority = "AUTHORITATIVE",
			Default = {
				BaseSpeed = 0,
				CurrentSpeed = 0,
			},
		},
		MoveIntent = {
			ECSName = "Movement.MoveIntent",
			Authority = "AUTHORITATIVE",
			Default = {
				SourceEntity = 0,
				GoalPosition = nil,
				MovementMode = "Path",
				ActionId = nil,
				Reason = nil,
				RequestedAt = 0,
				Status = "Requested",
			},
		},
		PathRuntimeState = {
			ECSName = "Movement.PathRuntimeState",
			Authority = "AUTHORITATIVE",
			Default = {
				Mode = nil,
				GoalPosition = nil,
				RequestedAt = 0,
				StartedAt = nil,
				UpdatedAt = nil,
				Status = "Idle",
				FailureReason = nil,
			},
		},
		FlowGridState = {
			ECSName = "Movement.FlowGridState",
			Authority = "AUTHORITATIVE",
			Default = {
				Revision = 0,
				Ready = false,
				UpdatedAt = nil,
				FailureReason = nil,
			},
		},
		FlowCalculationState = {
			ECSName = "Movement.FlowCalculationState",
			Authority = "AUTHORITATIVE",
			Default = {
				RequestedAt = 0,
				UpdatedAt = nil,
				Status = "Idle",
				IsDone = false,
				FailureReason = nil,
			},
		},
		ApplyState = {
			ECSName = "Movement.ApplyState",
			Authority = "AUTHORITATIVE",
			Default = {
				RequestedAt = 0,
				UpdatedAt = nil,
				Status = "Idle",
				TargetPosition = nil,
				VelocityXZ = nil,
				WalkSpeed = nil,
				IsMoving = false,
				IsDone = false,
				FailureReason = nil,
			},
		},
		ApplyResult = {
			ECSName = "Movement.ApplyResult",
			Authority = "AUTHORITATIVE",
			Default = {
				RequestedAt = 0,
				UpdatedAt = nil,
				Status = "Idle",
				IsMoving = false,
				IsDone = false,
				FailureReason = nil,
			},
		},
	},
	Tags = {},
	Archetypes = {},
}

return table.freeze(MovementEntitySchema)
