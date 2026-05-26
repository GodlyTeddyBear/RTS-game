--!strict

local EntityProofSchema = {
	FeatureName = "EntityProof",
	Components = {},
	Tags = {},
	Archetypes = {
		ProofActor = {
			Extends = "Entity.AIActive",
			Components = {},
			Tags = {},
		},
	},
}

return table.freeze(EntityProofSchema)
