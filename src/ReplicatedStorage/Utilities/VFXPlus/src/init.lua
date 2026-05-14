--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Cleanup = require(script.Cleanup)
local Playback = require(script.Playback)
local Policies = require(script.Policies)
local Setup = require(script.Setup)
local Types = require(script.Types)
local Enums = require(script.Enums)

type TRuntimeFolderOptions = Types.TRuntimeFolderOptions
type TPreparedVFXRequest = Types.TPreparedVFXRequest
type TVFXHandle = Types.TVFXHandle
type TVFXRegistry = Types.TVFXRegistry
type TVFXRequest = Types.TVFXRequest

local VFXPlus = {
	EffectCategory = Enums.EffectCategory,
	ErrorKey = Enums.ErrorKey,
}

function VFXPlus.Prepare(registry: TVFXRegistry, request: TVFXRequest): Result.Result<TPreparedVFXRequest>
	return Policies.Prepare(registry, request)
end

function VFXPlus.Spawn(registry: TVFXRegistry, request: TVFXRequest): Result.Result<TVFXHandle>
	return Policies.PrepareSpawn(registry, request):andThen(function(preparedRequest: TPreparedVFXRequest)
		return Playback.Play(registry, preparedRequest)
	end)
end

function VFXPlus.Attach(registry: TVFXRegistry, request: TVFXRequest): Result.Result<TVFXHandle>
	return Policies.PrepareAttach(registry, request):andThen(function(preparedRequest: TPreparedVFXRequest)
		return Playback.Play(registry, preparedRequest)
	end)
end

function VFXPlus.ResolveLifetime(container: Instance, lifetimeOverride: number?): number
	return Playback.ResolveLifetime(container, lifetimeOverride)
end

function VFXPlus.EmitConfiguredBursts(container: Instance, emitCountOverride: number?)
	Playback.EmitConfiguredBursts(container, emitCountOverride)
end

function VFXPlus.ScheduleCleanup(handle: TVFXHandle, delaySeconds: number?): Result.Result<TVFXHandle>
	return Cleanup.Schedule(handle, delaySeconds)
end

function VFXPlus.EnsureRuntimeFolder(
	parent: Instance?,
	name: string?,
	options: TRuntimeFolderOptions?
): Result.Result<Folder>
	return Setup.EnsureRuntimeFolder(parent, name, options)
end

function VFXPlus.CreateEffectRegistry(effectsFolder: Folder): Result.Result<TVFXRegistry>
	return Setup.CreateEffectRegistry(effectsFolder)
end

return table.freeze(VFXPlus)
