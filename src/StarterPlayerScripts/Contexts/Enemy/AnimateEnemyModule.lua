--!strict

--[[
	Module: AnimateEnemyModule
	Purpose: Bridges enemy locomotion models to the shared client animation driver preset.
	Used In System: Called by EnemyAnimationController when a replicated enemy model becomes trackable.
	Boundaries: Owns animation driver setup only; does not own model discovery, tracking, or cleanup lifecycle.
]] 

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- [Dependencies]
--[=[
	@class AnimateEnemyModule
	Starts the shared enemy locomotion animation driver for a tracked client model.
	@client
]=]
local AnimateEnemyModule = {}

local animationController = nil

local function _GetAnimationController()
	if animationController == nil then
		animationController = Knit.GetController("AnimationController")
	end

	return animationController
end

-- [Public API]

--[=[
	@within AnimateEnemyModule
	Starts the enemy locomotion animation driver for a tracked enemy model.
	@param model Model -- Enemy model to animate.
	@param context any -- Animation driver context passed through to the shared setup routine.
	@return Promise -- Promise that resolves with the cleanup handle from the shared animation driver.
]=]
function AnimateEnemyModule.setup(model: Model, context: any)
	return _GetAnimationController():Setup(model, "EnemyLocomotion", context)
end

return AnimateEnemyModule
