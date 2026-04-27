--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)
local AnimationStatePlayer = require(script.Parent.Parent.Parent.Infrastructure.AnimationStatePlayer)

type TAnimationPreset = Types.TAnimationPreset

local BindAnimationStateCommand = {}
BindAnimationStateCommand.__index = BindAnimationStateCommand

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
	preset: TAnimationPreset
)
	AnimationStatePlayer.Bind(model, janitor, action, validActions, core, validCoreStates, context, preset)
end

return BindAnimationStateCommand
