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
			Authority = "DERIVED",
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
		DeathEventRequest = {
			ECSName = "Enemy.DeathEventRequest",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				EnemyEntity = 0,
				OutcomeId = "",
				CreatedAt = 0,
				ExpiresAt = nil,
			},
		},
	},
	Tags = {
		AliveTag = {},
		GoalReachedTag = {},
		RequestTag = {
			Replication = "ServerOnly",
		},
		ProcessedTag = {
			Replication = "ServerOnly",
		},
	},
	Archetypes = {
		Actor = {
			Extends = "Entity.Targetable",
			Components = {
				Role = true,
				PathState = true,
				CurrentMoveSpeed = true,
				AttackCooldown = true,
			},
			Tags = {
				AliveTag = true,
			},
		},
		DeathEventRequest = {
			Components = {
				DeathEventRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
	},
}

return table.freeze(EnemyEntitySchema)
