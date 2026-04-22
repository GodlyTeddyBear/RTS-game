--!strict

--[[
	Module: AnimateEnemyModule
	Purpose: Bridges enemy locomotion models to the shared client animation driver preset.
	Used In System: Called by EnemyAnimationController when a replicated enemy model becomes trackable.
	Boundaries: Owns animation driver setup only; does not own model discovery, tracking, or cleanup lifecycle.
]]

local AnimationDriver = require(script.Parent.Parent.Animation.Infrastructure.AnimationDriver)
local AnimationPresets = require(script.Parent.Parent.Animation.Infrastructure.AnimationPresets)

-- [Dependencies]
--[=[
	@class AnimateEnemyModule
	Starts the shared enemy locomotion animation driver for a tracked client model.
	@client
]=]
local AnimateEnemyModule = {}

-- [Public API]

--[=[
	@within AnimateEnemyModule
	Starts the enemy locomotion animation driver for a tracked enemy model.
	@param model Model -- Enemy model to animate.
	@param context any -- Animation driver context passed through to the shared setup routine.
	@return Promise -- Promise that resolves with the cleanup handle from the shared animation driver.
]=]
function AnimateEnemyModule.setup(model: Model, context: any)
	return AnimationDriver.setup(model, AnimationPresets.EnemyLocomotion, context)
end

return AnimateEnemyModule
