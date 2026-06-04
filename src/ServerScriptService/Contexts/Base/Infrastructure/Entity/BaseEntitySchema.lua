--!strict

local BaseEntitySchema = {
	FeatureName = "Base",
	Components = {
		State = {
			ECSName = "Base.State",
			Authority = "AUTHORITATIVE",
			Default = {
				BaseId = "",
			},
		},
		AnchorRef = {
			ECSName = "Base.AnchorRef",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Anchor = nil,
			},
		},
		MapInstanceRef = {
			ECSName = "Base.MapInstanceRef",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Instance = nil,
			},
		},
	},
	Tags = {
		BaseTag = {},
		DestroyedTag = {},
	},
	Archetypes = {
		Actor = {
			Extends = "Entity.Actor",
			Components = {
				State = true,
				AnchorRef = true,
				MapInstanceRef = true,
			},
			Tags = {
				BaseTag = true,
			},
		},
	},
}

return table.freeze(BaseEntitySchema)
