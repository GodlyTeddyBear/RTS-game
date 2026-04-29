--!strict

--[[
	Module: AnimateStructureModule
	Purpose: Bridges placed structure models to the shared client animation driver preset.
	Used In System: Called by StructureAnimationController when a replicated structure model becomes trackable.
	Boundaries: Owns animation driver setup only; does not own model discovery, targeting, or cleanup lifecycle.
]] 

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ResolveStructureAimRequest = require(script.Parent.Infrastructure.ResolveStructureAimRequest)

local AnimateStructureModule = {}

local animationController = nil

local function _GetAnimationController()
	if animationController == nil then
		animationController = Knit.GetController("AnimationController")
	end

	return animationController
end

function AnimateStructureModule.setup(model: Model, context: any)
	return _GetAnimationController():Setup(model, "Structure", context):andThen(function(animationCleanup)
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
