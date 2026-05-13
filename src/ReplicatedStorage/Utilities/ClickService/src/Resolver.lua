--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Option = require(ReplicatedStorage.Utilities.Option)

local Types = require(script.Parent.Types)

type TClickTarget = Types.TClickTarget
type TResolvePartCallback = Types.TResolvePartCallback

local Resolver = {}

function Resolver.ResolveTarget(target: TClickTarget, resolvePart: TResolvePartCallback?): any
	if target:IsA("BasePart") then
		return Option.Some(target)
	end

	local model = target :: Model
	if model.PrimaryPart ~= nil then
		return Option.Some(model.PrimaryPart)
	end

	if resolvePart ~= nil then
		return resolvePart(target)
	end

	return Option.None
end

return table.freeze(Resolver)
