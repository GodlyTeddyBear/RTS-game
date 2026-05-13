--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Errors)
local Types = require(script.Parent.Types)

type TDetectorBinding = Types.TDetectorBinding
type TResolvedClickOptions = Types.TResolvedClickOptions

local Detector = {}

local function _ApplyOptions(detector: ClickDetector, options: TResolvedClickOptions)
	detector.Name = options.Name
	if options.MaxActivationDistance ~= nil then
		detector.MaxActivationDistance = options.MaxActivationDistance
	end
	if options.CursorIcon ~= nil then
		detector.CursorIcon = options.CursorIcon
	end
end

function Detector.EnsureDetector(
	target: Instance,
	resolvedPart: BasePart,
	options: TResolvedClickOptions
): Result.Result<TDetectorBinding>
	local existingChild = resolvedPart:FindFirstChild(options.Name)
	local detector = existingChild :: ClickDetector?
	local created = false

	if detector == nil then
		detector = Instance.new("ClickDetector")
		created = true
	end

	local success, errorMessage = pcall(function()
		_ApplyOptions(detector :: ClickDetector, options)
		if (detector :: ClickDetector).Parent ~= resolvedPart then
			(detector :: ClickDetector).Parent = resolvedPart
		end
	end)

	if not success then
		if created and detector ~= nil and detector.Parent ~= nil then
			detector:Destroy()
		end

		local errorType, message, data = Errors.BuildDetectorResolutionFailed(
			target,
			resolvedPart,
			options.Name,
			detector,
			tostring(errorMessage)
		)
		return Result.Err(errorType, message, data)
	end

	return Result.Ok({
		Detector = detector :: ClickDetector,
		Created = created,
	})
end

return table.freeze(Detector)
