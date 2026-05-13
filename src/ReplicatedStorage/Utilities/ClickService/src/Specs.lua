--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Specification = require(ReplicatedStorage.Utilities.Specification)

local Enums = require(script.Parent.Enums)

local Specs = {}

local function _ErrorName(errorKey: any): string
	return errorKey.Name
end

function Specs.IsValidTarget(target: any): boolean
	return typeof(target) == "Instance" and (target:IsA("BasePart") or target:IsA("Model"))
end

function Specs.IsValidConfig(config: any): boolean
	return config == nil or type(config) == "table"
end

function Specs.IsValidDetectorName(detectorName: any): boolean
	return detectorName == nil or (type(detectorName) == "string" and detectorName ~= "")
end

function Specs.IsValidMaxActivationDistance(maxActivationDistance: any): boolean
	return maxActivationDistance == nil or (type(maxActivationDistance) == "number" and maxActivationDistance > 0)
end

function Specs.IsValidCursorIcon(cursorIcon: any): boolean
	return cursorIcon == nil or type(cursorIcon) == "string"
end

function Specs.IsValidResolvePart(resolvePart: any): boolean
	return resolvePart == nil or type(resolvePart) == "function"
end

function Specs.IsValidResolvedPart(resolvedPart: any): boolean
	return typeof(resolvedPart) == "Instance"
		and resolvedPart:IsA("BasePart")
		and resolvedPart.Parent ~= nil
end

function Specs.IsValidDetectorCandidate(existingChild: any): boolean
	return existingChild == nil or (typeof(existingChild) == "Instance" and existingChild:IsA("ClickDetector"))
end

function Specs.IsServiceAlive(isDestroyed: boolean): boolean
	return not isDestroyed
end

function Specs.IsHandleAlive(isDestroyed: boolean): boolean
	return not isDestroyed
end

function Specs.IsLegalTransition(currentState: any, nextState: any, canTransition: boolean): boolean
	if currentState == Enums.HandleState.Destroyed then
		return false
	end

	return canTransition
end

local HasValidConfig = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidConfig),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidConfig],
	function(candidate): boolean
		return Specs.IsValidConfig(candidate.Config)
	end
)

local HasValidTarget = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidTarget),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidTarget],
	function(candidate): boolean
		return Specs.IsValidTarget(candidate.Target)
	end
)

local HasValidDetectorName = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidDetectorName),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidDetectorName],
	function(candidate): boolean
		return Specs.IsValidDetectorName(candidate.DetectorName)
	end
)

local HasValidMaxActivationDistance = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMaxActivationDistance),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMaxActivationDistance],
	function(candidate): boolean
		return Specs.IsValidMaxActivationDistance(candidate.MaxActivationDistance)
	end
)

local HasValidCursorIcon = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidCursorIcon),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidCursorIcon],
	function(candidate): boolean
		return Specs.IsValidCursorIcon(candidate.CursorIcon)
	end
)

local HasValidResolvePart = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidResolvePart),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidResolvePart],
	function(candidate): boolean
		return Specs.IsValidResolvePart(candidate.ResolvePart)
	end
)

local HasValidResolvedPart = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidResolvedPart),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidResolvedPart],
	function(candidate): boolean
		return Specs.IsValidResolvedPart(candidate.ResolvedPart)
	end
)

local HasValidDetectorCandidate = Specification.new(
	_ErrorName(Enums.ErrorKey.ClickDetectorConflict),
	Enums.ErrorMessage[Enums.ErrorKey.ClickDetectorConflict],
	function(candidate): boolean
		return Specs.IsValidDetectorCandidate(candidate.ExistingChild)
	end
)

local HasAliveService = Specification.new(
	_ErrorName(Enums.ErrorKey.ClickServiceDestroyed),
	Enums.ErrorMessage[Enums.ErrorKey.ClickServiceDestroyed],
	function(candidate): boolean
		return Specs.IsServiceAlive(candidate.IsDestroyed)
	end
)

local HasAliveHandle = Specification.new(
	_ErrorName(Enums.ErrorKey.ClickHandleDestroyed),
	Enums.ErrorMessage[Enums.ErrorKey.ClickHandleDestroyed],
	function(candidate): boolean
		return Specs.IsHandleAlive(candidate.IsDestroyed)
	end
)

local HasLegalTransition = Specification.new(
	_ErrorName(Enums.ErrorKey.IllegalClickHandleTransition),
	Enums.ErrorMessage[Enums.ErrorKey.IllegalClickHandleTransition],
	function(candidate): boolean
		return Specs.IsLegalTransition(candidate.CurrentState, candidate.NextState, candidate.CanTransition)
	end
)

Specs.HasValidConfigSpec = HasValidConfig
Specs.HasValidTargetSpec = HasValidTarget
Specs.HasValidDetectorNameSpec = HasValidDetectorName
Specs.HasValidMaxActivationDistanceSpec = HasValidMaxActivationDistance
Specs.HasValidCursorIconSpec = HasValidCursorIcon
Specs.HasValidResolvePartSpec = HasValidResolvePart
Specs.HasValidResolvedPartSpec = HasValidResolvedPart
Specs.HasValidDetectorCandidateSpec = HasValidDetectorCandidate
Specs.HasAliveServiceSpec = HasAliveService
Specs.HasAliveHandleSpec = HasAliveHandle
Specs.HasLegalTransitionSpec = HasLegalTransition
Specs.HasValidClickOptions = Specification.All({
	HasValidConfig,
	HasValidDetectorName,
	HasValidMaxActivationDistance,
	HasValidCursorIcon,
	HasValidResolvePart,
})

return table.freeze(Specs)
