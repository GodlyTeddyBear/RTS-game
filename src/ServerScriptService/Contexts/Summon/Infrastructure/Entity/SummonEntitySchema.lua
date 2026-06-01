--!strict

local SummonEntitySchema = {
	FeatureName = "Summon",
	Components = {
		Kind = {
			ECSName = "Summon.Kind",
			Authority = "AUTHORITATIVE",
			Default = {
				Kind = "SwarmDrone",
			},
		},
		CombatProfile = {
			ECSName = "Summon.CombatProfile",
			Authority = "AUTHORITATIVE",
			Default = {
				MoveSpeed = 0,
				AcquireRange = 0,
				AttackRange = 0,
				AttackInterval = 0,
				DamagePerHit = 0,
			},
		},
		AttackCooldown = {
			ECSName = "Summon.AttackCooldown",
			Authority = "AUTHORITATIVE",
			Default = {
				LastAttackAt = 0,
			},
		},
		TargetEnemyId = {
			ECSName = "Summon.TargetEnemyId",
			Authority = "DERIVED",
			Default = nil,
		},
		EngageState = {
			ECSName = "Summon.EngageState",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "EngageEnemy",
				SourceEntity = 0,
				TargetEntity = nil,
				TargetPosition = nil,
				RequestedAt = 0,
				StartedAt = 0,
				UpdatedAt = nil,
				Status = "Started",
			},
		},
	},
	Tags = {
		DroneTag = {},
	},
	Archetypes = {
		Drone = {
			Extends = "Entity.OwnedActor",
			Components = {
				Lifetime = true,
				Kind = true,
				CombatProfile = true,
				AttackCooldown = true,
				TargetEnemyId = true,
				EngageState = true,
			},
			Tags = {
				DroneTag = true,
			},
		},
	},
}

return table.freeze(SummonEntitySchema)
