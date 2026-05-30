--!strict

local CombatEntitySchema = {
	FeatureName = "Combat",
	Components = {
		AttackState = {
			ECSName = "Combat.AttackState",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "",
				SourceEntity = 0,
				TargetEntity = nil,
				Phase = "Startup",
				Elapsed = 0,
				Damage = 0,
				Range = 0,
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
				AttackerEntity = 0,
				VictimEntity = 0,
				Amount = 0,
				CreatedAt = 0,
				Reason = "Combat",
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
	},
}

return table.freeze(CombatEntitySchema)
