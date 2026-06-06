--!strict

--[=[
	@class RunTravelConfig
	Defines the shared teleport destinations for the Phase 2 lobby handoff.
	@server
	@client
]=]

local RunTravelConfig = {}

--[=[
	@prop PHASE2_ENTRY_CFRAME CFrame
	@within RunTravelConfig
	Fallback Phase 2 entry spawn used until a Studio marker exists.
]=]
RunTravelConfig.PHASE2_ENTRY_CFRAME = CFrame.new(0, 10, 256)

--[=[
	@prop LOBBY_RETURN_CFRAME CFrame
	@within RunTravelConfig
	Fallback lobby return spawn used until a Studio marker exists.
]=]
RunTravelConfig.LOBBY_RETURN_CFRAME = CFrame.new(0, 10, 0)

return table.freeze(RunTravelConfig)
