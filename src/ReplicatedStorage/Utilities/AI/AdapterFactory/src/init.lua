--!strict

--[=[
	@class AiAdapterFactoryEntry
	Module table that exposes the shared adapter-builder constructor and types.
	@prop Types AiAdapterFactoryTypes -- Shared type definitions for the module surface
	@server
	@client
]=]

local Factory = require(script.Factory)
local Types = require(script.Types)

local AiAdapterFactory = {
	Types = Types,
}

export type TActionState = Types.TActionState
export type TActorAdapter = Types.TActorAdapter
export type TConfig = Types.TConfig

--[=[
	Builds a plain actor adapter that matches the `AiRuntime` adapter contract.
	@within AiAdapterFactoryEntry
	@param config TConfig -- Explicit callback bundle used to build the adapter
	@return TActorAdapter -- Adapter table ready for `AiRuntime:RegisterActorType`
]=]
function AiAdapterFactory.Create(config: TConfig): TActorAdapter
	return Factory.Create(config)
end

return table.freeze(AiAdapterFactory)
