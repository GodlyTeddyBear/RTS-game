--!strict

--[=[
	@class VFXPlus
	Shared visual-effect playback helpers for preparing, spawning, attaching,
	emitting, timing, and explicitly cleaning up cloned VFX containers.
	@server
	@client
]=]

local VFXPlus = require(script.src)
local Types = require(script.src.Types)

export type TEffectCategory = Types.TEffectCategory
export type TVFXRegistry = Types.TVFXRegistry
export type TVFXRequest = Types.TVFXRequest
export type TRuntimeFolderOptions = Types.TRuntimeFolderOptions
export type TPreparedVFXRequest = Types.TPreparedVFXRequest
export type TResolvedAttachTarget = Types.TResolvedAttachTarget
export type TVFXHandle = Types.TVFXHandle

return VFXPlus
