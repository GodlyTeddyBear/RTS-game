--!strict

local AnimationDriver = require(script.Parent.Parent.Animation.Infrastructure.AnimationDriver)
local AnimationPresets = require(script.Parent.Parent.Animation.Infrastructure.AnimationPresets)

local AnimatePlayerModule = {}

function AnimatePlayerModule.setup(character: Model, animationsFolder: Folder, context: any)
	return AnimationDriver.setup(character, AnimationPresets.Player(animationsFolder), context)
end

return AnimatePlayerModule
