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

type TAnimationStateSource = Types.TAnimationStateSource

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

function AnimateStructureModule.setup(model: Model, context: any, structureReplicationClient: any)
	return _GetAnimationController():Setup(model, "Structure", context, {
		StateSource = _CreateStructureStateSource(model, structureReplicationClient),
	}):andThen(function(animationCleanup)
		local aimCleanup = nil
		local aimRequest = ResolveStructureAimRequest.Execute(model, context)
		if aimRequest ~= nil then
			aimCleanup = _GetAnimationController():SetupAim(aimRequest)
		end

		return function()
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
