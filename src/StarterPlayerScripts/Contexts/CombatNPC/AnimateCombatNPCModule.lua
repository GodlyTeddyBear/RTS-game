--!strict

local AnimationDriver = require(script.Parent.Parent.Animation.Infrastructure.AnimationDriver)
local AnimationPresets = require(script.Parent.Parent.Animation.Infrastructure.AnimationPresets)

local AnimateCombatNPCModule = {}

function AnimateCombatNPCModule.setup(model: Model, context: any)
	return AnimationDriver.setup(model, AnimationPresets.CombatNPC, context)
end

return AnimateCombatNPCModule
