--!strict

--[=[
	@class Errors
	Defines the Run context error constants used across application and domain layers.
	@server
]=]
return table.freeze({
	ILLEGAL_TRANSITION = "RunContext: illegal state transition attempted",
	INVALID_STATE_FOR_START = "RunContext: start requested from invalid state",
	INVALID_STATE_FOR_NOTIFY = "RunContext: notify called from invalid state",
})
