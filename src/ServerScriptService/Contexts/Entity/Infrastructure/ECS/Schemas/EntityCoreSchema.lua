--!strict

local EntityCoreSchema = {
	FeatureName = "Entity",
	Components = {
		Identity = {
			ECSName = "Entity.Identity",
			Authority = "AUTHORITATIVE",
			Default = {
				EntityId = "",
				EntityKind = "",
				DefinitionId = nil,
			},
		},
		Ownership = {
			ECSName = "Entity.Ownership",
			Authority = "AUTHORITATIVE",
			Default = {
				Faction = nil,
				OwnerKind = nil,
				OwnerId = nil,
			},
		},
		Transform = {
			ECSName = "Entity.Transform",
			Authority = "DERIVED",
			Default = {
				CFrame = CFrame.identity,
			},
		},
		Health = {
			ECSName = "Entity.Health",
			Authority = "AUTHORITATIVE",
			Default = {
				Current = 0,
				Max = 0,
			},
		},
		Lifetime = {
			ECSName = "Entity.Lifetime",
			Authority = "AUTHORITATIVE",
			Default = {
				SpawnedAt = 0,
				ExpiresAt = nil,
			},
		},
		Target = {
			ECSName = "Entity.Target",
			Authority = "AUTHORITATIVE",
			Default = {
				TargetEntity = nil,
				TargetKind = nil,
			},
		},
		ModelRef = {
			ECSName = "Entity.ModelRef",
			Authority = "AUTHORITATIVE",
			Default = {
				Model = nil,
			},
		},
	},
	Tags = {
		ActiveTag = {},
		DirtyTag = {},
	},
	Archetypes = {
		Core = {
			Components = {
				Identity = true,
				Transform = true,
			},
			Tags = {
				ActiveTag = true,
			},
		},
		Actor = {
			Extends = "Core",
			Components = {
				Health = true,
				ModelRef = true,
			},
		},
		OwnedActor = {
			Extends = "Actor",
			Components = {
				Ownership = true,
			},
		},
		Targetable = {
			Extends = "Actor",
			Components = {
				Target = true,
			},
		},
		Timed = {
			Extends = "Core",
			Components = {
				Lifetime = true,
			},
		},
	},
}

return table.freeze(EntityCoreSchema)
