--!strict

local UnitEntitySchema = {
	FeatureName = "Unit",
	Components = {
		Role = {
			ECSName = "Unit.Role",
			Authority = "AUTHORITATIVE",
			Default = {
				Role = "",
				DisplayName = "",
				MaxHp = 0,
				UnitId = "",
				MovementMode = "Path",
				BuildWorkPerSecond = nil,
				BuildRange = nil,
			},
		},
		BaseMoveSpeed = {
			ECSName = "Unit.BaseMoveSpeed",
			Authority = "AUTHORITATIVE",
			Default = {
				Value = 0,
			},
		},
		CurrentMoveSpeed = {
			ECSName = "Unit.CurrentMoveSpeed",
			Authority = "AUTHORITATIVE",
			Default = {
				Value = 0,
			},
		},
		PathState = {
			ECSName = "Unit.PathState",
			Authority = "AUTHORITATIVE",
			Default = {
				GoalPosition = nil,
				RequestedGoalPosition = nil,
				GoalRevision = 0,
				FailedGoalRevision = nil,
				IsMoving = false,
			},
		},
		BuilderAssignment = {
			ECSName = "Unit.BuilderAssignment",
			Authority = "AUTHORITATIVE",
			Default = {
				TargetStructureEntity = nil,
			},
		},
		AnimationState = {
			ECSName = "Unit.AnimationState",
			Authority = "DERIVED",
			Default = "Idle",
		},
		AnimationLooping = {
			ECSName = "Unit.AnimationLooping",
			Authority = "DERIVED",
			Default = true,
		},
		LockOn = {
			ECSName = "Unit.LockOn",
			Authority = "AUTHORITATIVE",
			Default = {
				Attachment0 = nil,
				Attachment1 = nil,
				Constraint = nil,
			},
		},
	},
	Tags = {
		SelectableTag = {},
		MovableTag = {},
		GoalReachedTag = {},
	},
	Archetypes = {
		Actor = {
			Extends = "Entity.OwnedActor",
			Components = {
				Role = true,
				BaseMoveSpeed = true,
				CurrentMoveSpeed = true,
				PathState = true,
				BuilderAssignment = true,
				AnimationState = true,
				AnimationLooping = true,
				LockOn = true,
			},
			Tags = {
				SelectableTag = true,
				MovableTag = true,
			},
		},
	},
}

return table.freeze(UnitEntitySchema)
