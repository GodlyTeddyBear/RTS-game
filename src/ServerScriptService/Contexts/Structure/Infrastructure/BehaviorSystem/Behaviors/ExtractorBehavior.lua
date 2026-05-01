--!strict

--[=[
	@class ExtractorBehavior
	Defines the extractor runtime tree as a single looping extraction action.
	@server
]=]
local ExtractorBehavior = table.freeze({
	Sequence = {
		"StructureExtract",
	},
})

return ExtractorBehavior
