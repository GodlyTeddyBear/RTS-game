--!strict

--[[
	Module: AnimateUnitModule
	Purpose: Bridges replicated unit models to the shared client animation driver preset.
	Used In System: Called by UnitAnimationController when a replicated unit model becomes trackable.
	Boundaries: Owns animation driver setup only; does not own model discovery, tracking, or cleanup lifecycle.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AnimateUnitModule = {}

local animationController = nil

local function _GetAnimationController()
	if animationController == nil then
		animationController = Knit.GetController("AnimationController")
	end

	return animationController
end

function AnimateUnitModule.setup(model: Model, context: any)
	return _GetAnimationController():Setup(model, "CombatNPC", context)
end

return AnimateUnitModule
