--!strict

--[=[
	@class StasisBehavior
	Defines the stasis-field runtime tree as a single looping status aura action.
	@server
]=]
local StasisBehavior = table.freeze({
	Sequence = {
		"StructureStasis",
	},
})

return StasisBehavior
