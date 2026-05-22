--!strict

--[[
	Module: AnimateEnemyModule
	Purpose: Bridges enemy locomotion models to the shared client animation driver preset.
	Used In System: Called by EnemyAnimationController when a replicated enemy model becomes trackable.
	Boundaries: Owns animation driver setup only; does not own model discovery, tracking, or cleanup lifecycle.
]] 

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)

-- [Dependencies]
--[=[
	@class AnimateEnemyModule
	Starts the shared enemy locomotion animation driver for a tracked client model.
	@client
]=]
local AnimateEnemyModule = {}

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

local function _CreateEnemyStateSource(model: Model, enemyReplicationClient: any): TAnimationStateSource?
	if enemyReplicationClient == nil then
		return nil
	end

	local enemyId = model:GetAttribute("EnemyId")
	if type(enemyId) ~= "string" or enemyId == "" then
		return nil
	end

	local function getEnemyState()
		return enemyReplicationClient:GetEnemyState(enemyId)
	end

	return table.freeze({
		GetState = function(_self)
			local enemyState = getEnemyState()
			local animationState = if enemyState ~= nil then enemyState.AnimationState else nil
			if type(animationState) == "string" and animationState ~= "" then
				return animationState
			end

			return DEFAULT_ANIMATION_STATE
		end,
		GetLooping = function(_self)
			local enemyState = getEnemyState()
			local isLooping = if enemyState ~= nil then enemyState.IsAnimationLooping else nil
			if type(isLooping) == "boolean" then
				return isLooping
			end

			return DEFAULT_ANIMATION_LOOPING
		end,
		ObserveStateChanged = function(_, callback: () -> ())
			local connection = enemyReplicationClient:ObserveEnemyStateChanged(function(changedEnemyId: string)
				if changedEnemyId ~= enemyId then
					return
				end

				callback()
			end)

			return function()
				connection:Disconnect()
			end
		end,
		ObserveLoopingChanged = function(_, callback: () -> ())
			local connection = enemyReplicationClient:ObserveEnemyStateChanged(function(changedEnemyId: string)
				if changedEnemyId ~= enemyId then
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

-- [Public API]

--[=[
	@within AnimateEnemyModule
	Starts the enemy locomotion animation driver for a tracked enemy model.
	@param model Model -- Enemy model to animate.
	@param context any -- Animation driver context passed through to the shared setup routine.
	@return Promise -- Promise that resolves with the cleanup handle from the shared animation driver.
]=]
function AnimateEnemyModule.setup(model: Model, context: any, enemyReplicationClient: any)
	return _GetAnimationController():Setup(model, "EnemyLocomotion", context, {
		StateSource = _CreateEnemyStateSource(model, enemyReplicationClient),
	})
end

return AnimateEnemyModule
