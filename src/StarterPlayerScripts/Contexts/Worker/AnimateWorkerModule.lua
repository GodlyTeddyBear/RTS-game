--!strict

local AnimationDriver = require(script.Parent.Parent.Animation.Infrastructure.AnimationDriver)
local AnimationPresets = require(script.Parent.Parent.Animation.Infrastructure.AnimationPresets)

local AnimateWorkerModule = {}

function AnimateWorkerModule.setup(model: Model, context: any)
	return AnimationDriver.setup(model, AnimationPresets.Worker, context)
end

return AnimateWorkerModule
