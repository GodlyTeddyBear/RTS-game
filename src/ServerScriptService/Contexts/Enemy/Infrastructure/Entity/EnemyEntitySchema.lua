--!strict

local EnemyEntitySchema = {
	FeatureName = "Enemy",
	Components = {
		Role = {
			ECSName = "Enemy.Role",
			Authority = "AUTHORITATIVE",
			Default = {
				Role = "",
				WaveNumber = 0,
				MoveSpeed = 0,
				Damage = 0,
				AttackRange = 0,
				AttackCooldown = 0,
				TargetPreference = "",
				MovementMode = "",
			},
		},
		PathState = {
			ECSName = "Enemy.PathState",
			Authority = "AUTHORITATIVE",
			Default = {
				GoalPosition = nil,
				IsMoving = false,
			},
		},
		CurrentMoveSpeed = {
			ECSName = "Enemy.CurrentMoveSpeed",
			Authority = "AUTHORITATIVE",
			Default = {
				Value = 0,
			},
		},
		AttackCooldown = {
			ECSName = "Enemy.AttackCooldown",
			Authority = "AUTHORITATIVE",
			Default = {
				Cooldown = 0,
				LastAttackTime = 0,
			},
		},
		AdvanceState = {
			ECSName = "Enemy.AdvanceState",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "Advance",
				SourceEntity = 0,
				GoalPosition = nil,
				RequestedAt = 0,
				StartedAt = 0,
				UpdatedAt = nil,
				Status = "Started",
			},
		},
		AnimationState = {
			ECSName = "Enemy.AnimationState",
			Authority = "DERIVED",
			Default = "Idle",
		},
		AnimationLooping = {
			ECSName = "Enemy.AnimationLooping",
			Authority = "DERIVED",
			Default = true,
		},
	},
	Tags = {
		AliveTag = {},
		GoalReachedTag = {},
	},
	Archetypes = {
		Actor = {
			Extends = "Entity.Targetable",
			Components = {
				Role = true,
				PathState = true,
				CurrentMoveSpeed = true,
				AttackCooldown = true,
				AdvanceState = true,
				AnimationState = true,
				AnimationLooping = true,
			},
			Tags = {
				AliveTag = true,
			},
		},
	},
}

return table.freeze(EnemyEntitySchema)
