--!strict

local AnimationEntitySchema = {
	FeatureName = "Animation",
	Components = {
		Profile = {
			ECSName = "Animation.Profile",
			Authority = "AUTHORITATIVE",
			Default = {
				ProfileId = "",
				AnimationSetId = "",
				VariantId = nil,
				FeatureOverrides = nil,
			},
		},
		ActionChannels = {
			ECSName = "Animation.ActionChannels",
			Authority = "DERIVED",
			Default = {},
		},
	},
	Tags = {
		EnabledTag = {},
	},
	Archetypes = {},
}

return table.freeze(AnimationEntitySchema)
