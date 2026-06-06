--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)
local AnimationStatePlayer = require(script.Parent.Parent.Parent.Infrastructure.AnimationStatePlayer)

type TAnimationPreset = Types.TAnimationPreset
type TAnimationStateSource = Types.TAnimationStateSource

local BindAnimationStateCommand = {}
BindAnimationStateCommand.__index = BindAnimationStateCommand

local function _CreateAttributeStateSource(model: Model): TAnimationStateSource
	return table.freeze({
		GetState = function(_self)
			local state = model:GetAttribute("AnimationState")
			if type(state) == "string" and state ~= "" then
				return state
			end

			return "Idle"
		end,
		GetLooping = function(_self)
			local isLooping = model:GetAttribute("AnimationLooping")
			if type(isLooping) == "boolean" then
				return isLooping
			end

			return true
		end,
		GetRevision = function(_self)
			local revision = model:GetAttribute("AnimationRevision")
			return if type(revision) == "number" then revision else nil
		end,
		GetActionAnimation = function(_self)
			local state = model:GetAttribute("AnimationState")
			if type(state) ~= "string" or state == "" then
				return nil
			end
			local isLooping = model:GetAttribute("AnimationLooping")
			local revision = model:GetAttribute("AnimationRevision")
			return {
				State = state,
				Looping = if type(isLooping) == "boolean" then isLooping else true,
				Revision = if type(revision) == "number" then revision else 0,
			}
		end,
		ObserveStateChanged = function(_, callback: () -> ())
			local connection = model:GetAttributeChangedSignal("AnimationState"):Connect(callback)
			return function()
				connection:Disconnect()
			end
		end,
		ObserveLoopingChanged = function(_, callback: () -> ())
			local connection = model:GetAttributeChangedSignal("AnimationLooping"):Connect(callback)
			return function()
				connection:Disconnect()
			end
		end,
		ObserveRevisionChanged = function(_, callback: () -> ())
			local connection = model:GetAttributeChangedSignal("AnimationRevision"):Connect(callback)
			return function()
				connection:Disconnect()
			end
		end,
		ObserveActionAnimationChanged = function(_, callback: () -> ())
			local connections = {
				model:GetAttributeChangedSignal("AnimationState"):Connect(callback),
				model:GetAttributeChangedSignal("AnimationLooping"):Connect(callback),
				model:GetAttributeChangedSignal("AnimationRevision"):Connect(callback),
			}
			return function()
				for _, connection in connections do
					connection:Disconnect()
				end
			end
		end,
	})
end

function BindAnimationStateCommand.new()
	return setmetatable({}, BindAnimationStateCommand)
end

function BindAnimationStateCommand:Execute(
	model: Model,
	janitor: any,
	action: any,
	validActions: { [string]: boolean },
	core: any,
	validCoreStates: { [string]: boolean },
	context: any,
	preset: TAnimationPreset,
	stateSource: TAnimationStateSource?
)
	AnimationStatePlayer.Bind(
		model,
		janitor,
		action,
		validActions,
		core,
		validCoreStates,
		context,
		preset,
		if stateSource ~= nil then stateSource else _CreateAttributeStateSource(model)
	)
end

return BindAnimationStateCommand
