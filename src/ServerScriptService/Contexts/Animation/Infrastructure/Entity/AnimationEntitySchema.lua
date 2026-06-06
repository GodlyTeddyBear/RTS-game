--!strict

local AnimationEntitySchema = {
	FeatureName = "Animation",
	Components = {
		Profile = {
			ECSName = "Animation.Profile",
			Authority = "AUTHORITATIVE",
			Default = {
				PresetId = "",
				VariantId = nil,
				AssetSource = "ModelAnimations",
				AssetId = nil,
				StateMode = "ActionOnly",
				DisableDefaultAnimate = false,
			},
		},
		ActionState = {
			ECSName = "Animation.ActionState",
			Authority = "DERIVED",
			Default = {
				State = "",
				Looping = true,
				Revision = 0,
			},
		},
		AimProfile = {
			ECSName = "Animation.AimProfile",
			Authority = "AUTHORITATIVE",
			Default = {
				ProfileId = "",
				RigConfig = nil,
			},
		},
	},
	Tags = {
		EnabledTag = {},
	},
	Archetypes = {},
}

return table.freeze(AnimationEntitySchema)
