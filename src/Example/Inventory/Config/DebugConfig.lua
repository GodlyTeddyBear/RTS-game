--!strict

--[[
	Inventory Debug Configuration

	Controls debug logging for the Inventory context.
	Debug logs use print() and follow the format: [Context:Service] userId: X - milestone description

	Hierarchy:
	1. Master ENABLED flag (ReplicatedStorage/Config/DebugConfig.lua) must be true
	2. INVENTORY_ENABLED must be true
	3. Service-level flag must be true (e.g., ADD_ITEM)
	4. Milestone-level flag must be true (e.g., VALIDATION)
]]

return table.freeze({
	-- Context-level toggle
	INVENTORY_ENABLED = true,

	-- Service-level toggles
	ADD_ITEM = true,
	REMOVE_ITEM = true,
	TRANSFER_ITEM = true,
	STACK_ITEMS = true,
	CLEAR_INVENTORY = true,
	GET_INVENTORY = true,

	-- Milestone-level toggles
	VALIDATION = true,
	STACKING = true,
	SLOT_MANAGEMENT = true,
	ATOM_UPDATE = false, -- Usually too noisy
	PERSISTENCE = true,
})
