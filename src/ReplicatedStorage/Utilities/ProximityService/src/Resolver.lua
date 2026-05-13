--!strict

local Types = require(script.Parent.Types)

type TProximityTarget = Types.TProximityTarget
type TResolvePromptParentCallback = Types.TResolvePromptParentCallback
type TResolvedProximityOptions = Types.TResolvedProximityOptions

local Resolver = {}

local function _ApplyPromptOptions(prompt: ProximityPrompt, options: TResolvedProximityOptions)
	prompt.Name = options.PromptName
	prompt.ActionText = options.ActionText
	prompt.ObjectText = options.ObjectText
	prompt.HoldDuration = options.HoldDuration
	prompt.MaxActivationDistance = options.MaxActivationDistance
	prompt.RequiresLineOfSight = options.RequiresLineOfSight
	prompt.KeyboardKeyCode = options.KeyboardKeyCode
	prompt.GamepadKeyCode = options.GamepadKeyCode
	prompt.Exclusivity = options.Exclusivity
	prompt.Enabled = options.Enabled
end

function Resolver.ResolvePromptParent(
	target: TProximityTarget,
	resolveParent: TResolvePromptParentCallback?
): (BasePart | Attachment)?
	if target:IsA("BasePart") or target:IsA("Attachment") then
		return target
	end

	local model = target :: Model
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end

	if resolveParent ~= nil then
		return resolveParent(target)
	end

	return nil
end

function Resolver.CreatePrompt(parent: BasePart | Attachment, options: TResolvedProximityOptions): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	_ApplyPromptOptions(prompt, options)
	prompt.Parent = parent
	return prompt
end

function Resolver.ApplyPromptOptions(prompt: ProximityPrompt, options: TResolvedProximityOptions)
	_ApplyPromptOptions(prompt, options)
end

return table.freeze(Resolver)
