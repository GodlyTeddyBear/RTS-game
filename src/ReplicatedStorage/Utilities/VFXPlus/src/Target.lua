--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)

local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

type TResolvedAttachTarget = Types.TResolvedAttachTarget

local Target = {}

local function _BuildInvalidTargetResult(): Result.Result<TResolvedAttachTarget>
	return Result.Err(
		Enums.ErrorKey.InvalidAttachTarget.Name,
		Enums.ErrorMessage[Enums.ErrorKey.InvalidAttachTarget]
	)
end

local function _ResolveModelTarget(model: Model): Result.Result<TResolvedAttachTarget>
	local targetPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local ok, pivotCFrame = pcall(function()
		return ModelPlus.GetPivot(model)
	end)

	if ok then
		return Result.Ok({
			TargetPart = targetPart,
			CFrame = pivotCFrame,
		})
	end

	if targetPart ~= nil then
		return Result.Ok({
			TargetPart = targetPart,
			CFrame = targetPart.CFrame,
		})
	end

	return _BuildInvalidTargetResult()
end

function Target.Resolve(target: Instance): Result.Result<TResolvedAttachTarget>
	if target:IsA("BasePart") then
		local targetPart = target :: BasePart
		return Result.Ok({
			TargetPart = targetPart,
			CFrame = targetPart.CFrame,
		})
	end

	if target:IsA("Model") then
		return _ResolveModelTarget(target :: Model)
	end

	if target:IsA("Attachment") then
		local attachment = target :: Attachment
		local targetPart: BasePart? = nil
		local parent = attachment.Parent

		if parent ~= nil and parent:IsA("BasePart") then
			targetPart = parent
		end

		return Result.Ok({
			TargetPart = targetPart,
			CFrame = attachment.WorldCFrame,
		})
	end

	return _BuildInvalidTargetResult()
end

return table.freeze(Target)
