--!strict

local PlayerEntitySchema = {
	FeatureName = "Player",
	Components = {
		PlayerState = {
			ECSName = "Player.PlayerState",
			Authority = "AUTHORITATIVE",
			Default = {
				UserId = 0,
				Name = "",
			},
		},
	},
	Tags = {
		PlayerTag = {},
	},
	Archetypes = {
		Actor = {
			Extends = "Entity.OwnedActor",
			Components = {
				PlayerState = true,
			},
			Tags = {
				PlayerTag = true,
			},
		},
	},
}

return table.freeze(PlayerEntitySchema)
