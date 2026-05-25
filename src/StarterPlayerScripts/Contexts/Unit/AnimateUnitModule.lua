--!strict

--[=[
    @class AnimateUnitModule
    Bridges replicated unit models to the shared client animation driver preset.

    Called by `UnitAnimationController` when a replicated unit model becomes trackable.
    Owns animation driver setup only; does not own model discovery, tracking, or cleanup lifecycle.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)

local AnimateUnitModule = {}

local animationController = nil
local DEFAULT_ANIMATION_STATE = "Idle"
local DEFAULT_ANIMATION_LOOPING = true

type TAnimationStateSource = Types.TAnimationStateSource

-- Resolves the shared animation controller lazily so the module only pays the lookup cost when a unit is actually tracked.
local function _GetAnimationController()
	if animationController == nil then
		animationController = Knit.GetController("AnimationController")
	end

	return animationController
end

-- Builds a per-unit animation state source that reads replicated unit state and falls back to stable defaults.
local function _CreateUnitStateSource(model: Model, unitReplicationClient: any): TAnimationStateSource?
	if unitReplicationClient == nil then
		return nil
	end

	local unitGuid = model:GetAttribute("UnitGuid")
	if type(unitGuid) ~= "string" or unitGuid == "" then
		return nil
	end

	local function getUnitState()
		return unitReplicationClient:GetUnitState(unitGuid)
	end

	return table.freeze({
		GetState = function(_self)
			local unitState = getUnitState()
			local animationState = if unitState ~= nil then unitState.AnimationState else nil
			if type(animationState) == "string" and animationState ~= "" then
				return animationState
			end

			return DEFAULT_ANIMATION_STATE
		end,
		GetLooping = function(_self)
			local unitState = getUnitState()
			local isLooping = if unitState ~= nil then unitState.IsAnimationLooping else nil
			if type(isLooping) == "boolean" then
				return isLooping
			end

			return DEFAULT_ANIMATION_LOOPING
		end,
		ObserveStateChanged = function(_, callback: () -> ())
			local connection = unitReplicationClient:ObserveUnitStateChanged(function(changedUnitGuid: string)
				if changedUnitGuid ~= unitGuid then
					return
				end

				callback()
			end)

			return function()
				connection:Disconnect()
			end
		end,
		ObserveLoopingChanged = function(_, callback: () -> ())
			local connection = unitReplicationClient:ObserveUnitStateChanged(function(changedUnitGuid: string)
				if changedUnitGuid ~= unitGuid then
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

--[=[
    Attaches the shared animation driver to a replicated unit model.

    @within AnimateUnitModule
    @param model Model -- Replicated unit model to animate.
    @param context any -- Context forwarded to the shared animation controller.
    @param unitReplicationClient any -- Client used to read replicated unit animation state.
    @return any -- Cleanup handle returned by the shared animation controller.
]=]
function AnimateUnitModule.setup(model: Model, context: any, unitReplicationClient: any)
	return _GetAnimationController():Setup(model, "CombatNPC", context, {
		StateSource = _CreateUnitStateSource(model, unitReplicationClient),
	})
end

return AnimateUnitModule
