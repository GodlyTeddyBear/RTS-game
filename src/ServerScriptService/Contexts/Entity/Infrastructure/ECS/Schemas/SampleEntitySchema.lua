--!strict

return table.freeze({
	FeatureName = "Sample",
	Components = {
		IdentityComponent = {
			ECSName = "Sample.Identity",
			Authority = "AUTHORITATIVE",
			Default = {
				Id = "sample",
			},
		},
		HealthComponent = {
			ECSName = "Sample.Health",
			Authority = "AUTHORITATIVE",
			Default = {
				Current = 100,
				Max = 100,
			},
		},
	},
	Tags = {
		ActiveTag = {},
	},
	Archetypes = {
		BaseEntity = {
			Components = {
				IdentityComponent = true,
				HealthComponent = true,
			},
			Tags = {
				ActiveTag = true,
			},
		},
	},
})
