--!strict

--[[
	Module: AnimateStructureModule
	Purpose: Bridges placed structure models to the shared client animation driver preset.
	Used In System: Called by StructureAnimationController when a replicated structure model becomes trackable.
	Boundaries: Owns animation driver setup only; does not own model discovery, targeting, or cleanup lifecycle.
]] 

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)
local ResolveStructureAimRequest = require(script.Parent.Infrastructure.ResolveStructureAimRequest)

local AnimateStructureModule = {}

local animationController = nil
local DEFAULT_ANIMATION_STATE = "Idle"
local DEFAULT_ANIMATION_LOOPING = true
local CONSTRUCTION_BUCKET_SIZE = 10
local CONSTRUCTION_START_TRANSPARENCY = 0.95

type TAnimationStateSource = Types.TAnimationStateSource
type TTrackedPartEntry = {
	Part: BasePart,
	AuthoredTransparency: number,
}

local function _GetAnimationController()
	if animationController == nil then
		animationController = Knit.GetController("AnimationController")
	end

	return animationController
end

local function _ResolveStructureId(model: Model): string?
	local structureId = model:GetAttribute("StructureId")
	if type(structureId) == "string" and structureId ~= "" then
		return structureId
	end

	local placementInstanceId = model:GetAttribute("PlacementInstanceId")
	if type(placementInstanceId) == "number" then
		return tostring(placementInstanceId)
	end

	return nil
end

local function _CreateStructureStateSource(model: Model, structureReplicationClient: any): TAnimationStateSource?
	if structureReplicationClient == nil then
		return nil
	end

	local structureId = _ResolveStructureId(model)
	if structureId == nil then
		return nil
	end

	local function getStructureState()
		return structureReplicationClient:GetStructureState(structureId)
	end

	return table.freeze({
		GetState = function(_self)
			local structureState = getStructureState()
			local animationState = if structureState ~= nil then structureState.AnimationState else nil
			if type(animationState) == "string" and animationState ~= "" then
				return animationState
			end

			return DEFAULT_ANIMATION_STATE
		end,
		GetLooping = function(_self)
			local structureState = getStructureState()
			local isLooping = if structureState ~= nil then structureState.IsAnimationLooping else nil
			if type(isLooping) == "boolean" then
				return isLooping
			end

			return DEFAULT_ANIMATION_LOOPING
		end,
		ObserveStateChanged = function(_, callback: () -> ())
			local connection = structureReplicationClient:ObserveStructureStateChanged(function(changedStructureId: string)
				if changedStructureId ~= structureId then
					return
				end

				callback()
			end)

			return function()
				connection:Disconnect()
			end
		end,
		ObserveLoopingChanged = function(_, callback: () -> ())
			local connection = structureReplicationClient:ObserveStructureStateChanged(function(changedStructureId: string)
				if changedStructureId ~= structureId then
					return
				end

				callback()
			end)

			return function()
				connection:Disconnect()
			end
		end,
	})
end

local function _BuildEligiblePartEntries(model: Model): { TTrackedPartEntry }
	local entries = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			table.insert(entries, {
				Part = descendant,
				AuthoredTransparency = descendant.Transparency,
			})
		end
	end

	return entries
end

local function _ResolveBuildBucket(buildPercent: number): number
	return math.clamp(math.floor(buildPercent / CONSTRUCTION_BUCKET_SIZE) * CONSTRUCTION_BUCKET_SIZE, 0, 100)
end

local function _RestoreAuthoredTransparency(entries: { TTrackedPartEntry })
	for _, entry in entries do
		local part = entry.Part
		if part.Parent ~= nil then
			part.Transparency = entry.AuthoredTransparency
		end
	end
end

local function _ApplyConstructionTransparency(entries: { TTrackedPartEntry }, bucket: number)
	local alpha = math.clamp(bucket / 100, 0, 1)

	for _, entry in entries do
		local part = entry.Part
		if part.Parent == nil then
			continue
		end

		part.Transparency = CONSTRUCTION_START_TRANSPARENCY
			+ ((entry.AuthoredTransparency - CONSTRUCTION_START_TRANSPARENCY) * alpha)
	end
end

local function _AttachConstructionReveal(model: Model, structureReplicationClient: any): (() -> ())?
	if structureReplicationClient == nil then
		return nil
	end

	local structureId = _ResolveStructureId(model)
	if structureId == nil then
		return nil
	end

	local eligiblePartEntries = _BuildEligiblePartEntries(model)
	local lastAppliedBucket = nil :: number?
	local isRestored = false

	local function applyCurrentState()
		local structureState = structureReplicationClient:GetStructureState(structureId)
		if structureState == nil then
			return
		end

		if structureState.BuildState == "Completed" then
			if not isRestored then
				_RestoreAuthoredTransparency(eligiblePartEntries)
				isRestored = true
			end
			lastAppliedBucket = 100
			return
		end

		local nextBucket = _ResolveBuildBucket(structureState.BuildPercent)
		if lastAppliedBucket == nextBucket and not isRestored then
			return
		end

		_ApplyConstructionTransparency(eligiblePartEntries, nextBucket)
		lastAppliedBucket = nextBucket
		isRestored = false
	end

	applyCurrentState()

	local connection = structureReplicationClient:ObserveStructureStateChanged(function(changedStructureId: string)
		if changedStructureId ~= structureId then
			return
		end

		applyCurrentState()
	end)

	return function()
		connection:Disconnect()
		_RestoreAuthoredTransparency(eligiblePartEntries)
	end
end

function AnimateStructureModule.setup(model: Model, context: any, structureReplicationClient: any)
	return _GetAnimationController():Setup(model, "Structure", context, {
		StateSource = _CreateStructureStateSource(model, structureReplicationClient),
	}):andThen(function(animationCleanup)
		local aimCleanup = nil
		local constructionRevealCleanup = _AttachConstructionReveal(model, structureReplicationClient)
		local aimRequest = ResolveStructureAimRequest.Execute(model, context)
		if aimRequest ~= nil then
			aimCleanup = _GetAnimationController():SetupAim(aimRequest)
		end

		return function()
			if constructionRevealCleanup ~= nil then
				constructionRevealCleanup()
			end
			if aimCleanup ~= nil then
				aimCleanup()
			end
			if animationCleanup ~= nil then
				animationCleanup()
			end
		end
	end)
end

return AnimateStructureModule
