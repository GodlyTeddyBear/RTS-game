--!strict

local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

type TClickErrorData = Types.TClickErrorData

local Errors = {}

local function _BuildErrorData(data: TClickErrorData): TClickErrorData
	return table.freeze({
		Target = data.Target,
		ResolvedPart = data.ResolvedPart,
		Detector = data.Detector,
		DetectorName = data.DetectorName,
		Reason = data.Reason,
		State = data.State,
	})
end

local function _BuildError(errorKey: any, message: string?, data: TClickErrorData?): (string, string, TClickErrorData?)
	return errorKey.Name, message or Enums.ErrorMessage[errorKey], if data ~= nil then _BuildErrorData(data) else nil
end

function Errors.BuildTargetResolutionFailed(
	target: Instance?,
	detectorName: string?,
	reason: string
): (string, string, TClickErrorData?)
	return _BuildError(Enums.ErrorKey.ClickTargetResolutionFailed, nil, {
		Target = target,
		DetectorName = detectorName,
		Reason = reason,
	})
end

function Errors.BuildTargetDestroyed(
	target: Instance?,
	resolvedPart: BasePart?,
	detectorName: string?,
	reason: string
): (string, string, TClickErrorData?)
	return _BuildError(Enums.ErrorKey.ClickTargetDestroyed, nil, {
		Target = target,
		ResolvedPart = resolvedPart,
		DetectorName = detectorName,
		Reason = reason,
	})
end

function Errors.BuildDetectorConflict(
	target: Instance?,
	resolvedPart: BasePart,
	detectorName: string,
	reason: string
): (string, string, TClickErrorData?)
	return _BuildError(Enums.ErrorKey.ClickDetectorConflict, nil, {
		Target = target,
		ResolvedPart = resolvedPart,
		DetectorName = detectorName,
		Reason = reason,
	})
end

function Errors.BuildDetectorResolutionFailed(
	target: Instance?,
	resolvedPart: BasePart?,
	detectorName: string?,
	detector: ClickDetector?,
	reason: string
): (string, string, TClickErrorData?)
	return _BuildError(Enums.ErrorKey.ClickDetectorResolutionFailed, nil, {
		Target = target,
		ResolvedPart = resolvedPart,
		Detector = detector,
		DetectorName = detectorName,
		Reason = reason,
	})
end

function Errors.BuildHandleDestroyed(
	target: Instance?,
	resolvedPart: BasePart?,
	detectorName: string?,
	state: string
): (string, string, TClickErrorData?)
	return _BuildError(Enums.ErrorKey.ClickHandleDestroyed, nil, {
		Target = target,
		ResolvedPart = resolvedPart,
		DetectorName = detectorName,
		State = state,
		Reason = "Handle is no longer usable",
	})
end

function Errors.BuildServiceDestroyed(
	target: Instance?,
	detectorName: string?
): (string, string, TClickErrorData?)
	return _BuildError(Enums.ErrorKey.ClickServiceDestroyed, nil, {
		Target = target,
		DetectorName = detectorName,
		Reason = "Service is no longer usable",
	})
end

function Errors.BuildIllegalTransition(
	target: Instance?,
	resolvedPart: BasePart?,
	detectorName: string?,
	state: string,
	reason: string
): (string, string, TClickErrorData?)
	return _BuildError(Enums.ErrorKey.IllegalClickHandleTransition, nil, {
		Target = target,
		ResolvedPart = resolvedPart,
		DetectorName = detectorName,
		State = state,
		Reason = reason,
	})
end

return table.freeze(Errors)
