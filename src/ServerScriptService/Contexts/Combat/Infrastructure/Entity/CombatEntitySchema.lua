--!strict

local CombatEntitySchema = {
	FeatureName = "Combat",
	Components = {
		AttackState = {
			ECSName = "Combat.AttackState",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "",
				AbilityId = "",
				Mechanic = "",
				SourceEntity = 0,
				TargetEntity = nil,
				TargetKind = nil,
				Phase = "Startup",
				Elapsed = 0,
				Damage = 0,
				Cooldown = 0,
				Range = 0,
				TargetPosition = nil,
				ProjectileId = nil,
				Animation = nil,
				RequestedAt = 0,
				StartedAt = 0,
				UpdatedAt = nil,
				HasEmittedRequest = false,
			},
		},
		HitboxSpawnRequest = {
			ECSName = "Combat.HitboxSpawnRequest",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "",
				AbilityId = "",
				SourceEntity = 0,
				TargetEntity = nil,
				Damage = 0,
				Range = 0,
				CreatedAt = 0,
				ExpiresAt = nil,
			},
		},
		ActiveHitboxState = {
			ECSName = "Combat.ActiveHitboxState",
			Authority = "AUTHORITATIVE",
			Default = {
				Handle = "",
				SourceEntity = 0,
				AbilityId = "",
				Damage = 0,
				CreatedAt = 0,
				ExpiresAt = nil,
			},
		},
		DamageRequest = {
			ECSName = "Combat.DamageRequest",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "",
				AbilityId = "",
				AttackerEntity = 0,
				VictimEntity = nil,
				VictimKind = nil,
				Amount = 0,
				CreatedAt = 0,
				Reason = "Combat",
			},
		},
		HealthDepletedRequest = {
			ECSName = "Combat.HealthDepletedRequest",
			Authority = "AUTHORITATIVE",
			Default = {
				VictimEntity = 0,
				VictimKind = "",
				CreatedAt = 0,
				ExpiresAt = nil,
			},
		},
		HealthDepletedOutcomeRequest = {
			ECSName = "Combat.HealthDepletedOutcomeRequest",
			Authority = "AUTHORITATIVE",
			Default = {
				VictimEntity = 0,
				VictimKind = "",
				OutcomeId = "",
				CreatedAt = 0,
				ExpiresAt = nil,
			},
		},
		GoalReachedOutcomeRequest = {
			ECSName = "Combat.GoalReachedOutcomeRequest",
			Authority = "AUTHORITATIVE",
			Default = {
				SourceEntity = 0,
				OutcomeId = "",
				ActionId = "",
				CreatedAt = 0,
				ExpiresAt = nil,
			},
		},
		BaseDamageRequest = {
			ECSName = "Combat.BaseDamageRequest",
			Authority = "AUTHORITATIVE",
			Default = {
				Amount = 0,
				CreatedAt = 0,
				ExpiresAt = nil,
			},
		},
		ProjectileSpawnRequest = {
			ECSName = "Combat.ProjectileSpawnRequest",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "",
				AbilityId = "",
				ProjectileId = "",
				SourceEntity = 0,
				TargetEntity = nil,
				Damage = 0,
				Range = 0,
				CreatedAt = 0,
				ExpiresAt = nil,
			},
		},
		ActiveProjectileState = {
			ECSName = "Combat.ActiveProjectileState",
			Authority = "AUTHORITATIVE",
			Default = {
				Handle = "",
				SourceEntity = 0,
				AbilityId = "",
				CreatedAt = 0,
			},
		},
		StatusAuraState = {
			ECSName = "Combat.StatusAuraState",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "Stasis",
				SourceEntity = 0,
				AuraType = "StasisField",
				StructureEntity = 0,
				RequestedAt = 0,
				StartedAt = 0,
				UpdatedAt = nil,
				Status = "Started",
			},
		},
	},
	Tags = {
		RequestTag = {},
		ProcessedTag = {},
	},
	Archetypes = {
		HitboxSpawnRequest = {
			Components = {
				HitboxSpawnRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
		DamageRequest = {
			Components = {
				DamageRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
		HealthDepletedRequest = {
			Components = {
				HealthDepletedRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
		HealthDepletedOutcomeRequest = {
			Components = {
				HealthDepletedOutcomeRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
		GoalReachedOutcomeRequest = {
			Components = {
				GoalReachedOutcomeRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
		BaseDamageRequest = {
			Components = {
				BaseDamageRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
		ActiveHitbox = {
			Components = {
				ActiveHitboxState = true,
			},
		},
		ProjectileSpawnRequest = {
			Components = {
				ProjectileSpawnRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
		ActiveProjectile = {
			Components = {
				ActiveProjectileState = true,
			},
		},
	},
}

return table.freeze(CombatEntitySchema)
