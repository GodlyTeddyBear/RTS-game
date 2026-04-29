--!strict

--[=[
	@class AiRuntimeEntry
	Module table that exposes the shared AI runtime constructor and types.
	@prop Types AiRuntimeTypes -- Shared type definitions for the module surface
	@server
	@client
]=]

local Runtime = require(script.Runtime)
local Types = require(script.Types)

local AiRuntime = {
	Types = Types,
}

export type TConfig = Types.TConfig
export type THook = Types.THook
export type THookContext = Types.THookContext
export type THookContribution = Types.THookContribution
export type TActorAdapter = Types.TActorAdapter
export type TFrameContext = Types.TFrameContext
export type TErrorSinkPayload = Types.TErrorSinkPayload
export type TRunFrameEntityResult = Types.TRunFrameEntityResult
export type TRunFrameResult = Types.TRunFrameResult
export type TCleanupKind = Types.TCleanupKind
export type TCleanupResult = Types.TCleanupResult
export type TCleanupBatchResult = Types.TCleanupBatchResult

--[=[
	Creates a runtime facade for the supplied condition, command, and hook registries.
	@within AiRuntimeEntry
	@param config TConfig -- Runtime configuration bundle used for tree compilation and frame orchestration
	@return AiRuntimeRuntime -- Runtime facade instance
]=]
function AiRuntime.new(config: TConfig)
	return Runtime.new(config)
end

return table.freeze(AiRuntime)
