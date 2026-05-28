--!strict

local EntityProofSchema = {
	FeatureName = "EntityProof",
	Components = {},
	Tags = {},
	Archetypes = {
		ProofActor = {
			Extends = "Entity.Actor",
			Components = {},
			Tags = {},
		},
	},
}

return table.freeze(EntityProofSchema)
