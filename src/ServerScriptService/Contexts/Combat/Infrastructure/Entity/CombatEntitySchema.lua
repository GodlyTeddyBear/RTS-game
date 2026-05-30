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
				Phase = "Startup",
				Elapsed = 0,
				Damage = 0,
				Cooldown = 0,
				Range = 0,
				ProjectileId = nil,
				Animation = nil,
				RequestedAt = 0,
				StartedAt = 0,
				UpdatedAt = nil,
				HasEmittedRequest = false,
			},
		},
		HitboxRequest = {
			ECSName = "Combat.HitboxRequest",
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
		DamageRequest = {
			ECSName = "Combat.DamageRequest",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "",
				AbilityId = "",
				AttackerEntity = 0,
				VictimEntity = 0,
				Amount = 0,
				CreatedAt = 0,
				Reason = "Combat",
			},
		},
		ProjectileRequest = {
			ECSName = "Combat.ProjectileRequest",
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
	},
	Tags = {
		RequestTag = {},
		ProcessedTag = {},
	},
	Archetypes = {
		HitboxRequest = {
			Components = {
				HitboxRequest = true,
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
		ProjectileRequest = {
			Components = {
				ProjectileRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
	},
}

return table.freeze(CombatEntitySchema)
