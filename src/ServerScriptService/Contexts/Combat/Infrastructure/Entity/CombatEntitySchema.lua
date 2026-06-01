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
				VictimEntity = nil,
				VictimKind = nil,
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
