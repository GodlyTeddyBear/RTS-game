--!strict

--[[
	NPCConfig - Frozen NPC identity configurations

	Maps NPCId → static identity data. Used by both server (validation)
	and client (display, dialogue tree lookup).

	NPCId must match the Model attribute "NPCId" in workspace.
]]

local NPCConfig = {
	Eldric = table.freeze({
		NPCId = "Eldric",
		DisplayName = "Eldric the Elder",
		Role = "Village Elder",
		Tags = { "NPC", "QuestGiver" },
		Description = "A wise elder who has protected the village for decades.",
	}),
}

-- Freeze each entry and the top-level table
table.freeze(NPCConfig)

return NPCConfig
