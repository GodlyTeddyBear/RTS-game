--!strict

--[[
	NPC Debug Configuration

	Controls debug logging for the NPC context.
	Debug logs use print() and follow the format: [NPC:Service] userId: X - milestone description

	Hierarchy:
	1. Master ENABLED flag (ReplicatedStorage/Config/DebugConfig.lua) must be true
	2. NPC_ENABLED must be true
	3. Service-level flag must be true (e.g., SET_FLAG)
	4. Milestone-level flag must be true (e.g., VALIDATION)
]]

return table.freeze({
	-- Context-level toggle
	NPC_ENABLED = true,

	-- Service-level toggles
	SET_FLAG = true,
	GET_FLAGS = true,
	INTERACT_WITH_NPC = true,

	-- Milestone-level toggles
	VALIDATION = true,
	ATOM_UPDATE = false, -- Usually too noisy
	PERSISTENCE = true,
	SYNC = false, -- Usually too noisy
})
