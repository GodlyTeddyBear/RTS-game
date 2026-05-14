--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)
local StashTypes = require(ReplicatedStorage.Utilities.StashPlus.src.Types)

local Types = require(script.Parent.Types)

type TPreparedVFXRequest = Types.TPreparedVFXRequest
type TVFXHandle = Types.TVFXHandle

type THandleInternal = TVFXHandle & {
	_isDestroyed: boolean,
}

local Handle = {}
local HandleMethods = {}
HandleMethods.__index = HandleMethods

function Handle.new(
	container: Folder | Model,
	anchor: Model,
	root: BasePart,
	lifetime: number,
	preparedRequest: TPreparedVFXRequest
): TVFXHandle
	local stash = StashPlus.new()
	stash:Add(anchor, "Destroy", {
		Key = "Anchor",
		Label = "VFXPlusAnchor",
	})

	local self = setmetatable({
		Container = container,
		Anchor = anchor,
		Root = root,
		Stash = stash,
		EffectKey = preparedRequest.EffectKey,
		Category = preparedRequest.Category,
		Lifetime = lifetime,
		AutoCleanup = preparedRequest.AutoCleanup,
		CleanupScheduled = false,
		Metadata = preparedRequest.Metadata,
		_isDestroyed = false,
	}, HandleMethods) :: any

	return self
end

function HandleMethods:Cleanup(): StashTypes.TCleanupReport
	local selfInternal = self :: THandleInternal
	selfInternal.CleanupScheduled = false
	return selfInternal.Stash:Cleanup()
end

function HandleMethods:Destroy(): StashTypes.TCleanupReport
	local selfInternal = self :: THandleInternal
	selfInternal._isDestroyed = true
	selfInternal.CleanupScheduled = false
	return selfInternal.Stash:Destroy()
end

function HandleMethods:IsDestroyed(): boolean
	local selfInternal = self :: THandleInternal
	return selfInternal._isDestroyed or selfInternal.Stash:IsDestroyed()
end

return table.freeze(Handle)
