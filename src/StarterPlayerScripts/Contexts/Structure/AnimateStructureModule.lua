--!strict

--[[
	Module: AnimateStructureModule
	Purpose: Bridges placed structure models to the shared client animation driver preset.
	Used In System: Called by StructureAnimationController when a replicated structure model becomes trackable.
	Boundaries: Owns animation driver setup only; does not own model discovery, targeting, or cleanup lifecycle.
]]

local AnimationDriver = require(script.Parent.Parent.Animation.Infrastructure.AnimationDriver)
local AnimationPresets = require(script.Parent.Parent.Animation.Infrastructure.AnimationPresets)

local AnimateStructureModule = {}

function AnimateStructureModule.setup(model: Model, context: any)
	return AnimationDriver.setup(model, AnimationPresets.Structure, context)
end

return AnimateStructureModule
