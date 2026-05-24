--!strict

local Relationship = table.freeze({
	Ally = "Ally",
	Neutral = "Neutral",
	Hostile = "Hostile",
})

local VALID_RELATIONSHIPS = table.freeze({
	[Relationship.Ally] = true,
	[Relationship.Neutral] = true,
	[Relationship.Hostile] = true,
})

local Relationships = {}

function Relationships.IsValidRelationship(relationship: string): boolean
	return VALID_RELATIONSHIPS[relationship] == true
end

Relationships.Relationship = Relationship

return table.freeze(Relationships)
