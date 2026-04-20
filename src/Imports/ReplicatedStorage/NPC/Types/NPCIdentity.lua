--!strict

--[[
	NPCIdentity - Type definition for NPC identity data

	Light identity: name, role, tags, description.
	No gameplay stats — NPCs are dialogue delivery vessels.
]]

export type TNPCIdentity = {
	NPCId: string,
	DisplayName: string,
	Role: string,
	Tags: { string },
	Description: string?,
}

return {}
