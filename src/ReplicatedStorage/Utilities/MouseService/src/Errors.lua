--!strict

local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

type TMouseErrorData = Types.TMouseErrorData

local Errors = {}

local function _BuildErrorData(data: TMouseErrorData?): TMouseErrorData?
	if data == nil then
		return nil
	end

	return table.freeze({
		ChannelName = data.ChannelName,
		ScreenPoint = data.ScreenPoint,
		RayLength = data.RayLength,
		Reason = data.Reason,
		State = data.State,
	})
end

local function _BuildError(errorKey: any, message: string?, data: TMouseErrorData?): (string, string, TMouseErrorData?)
	return errorKey.Name, message or Enums.ErrorMessage[errorKey], _BuildErrorData(data)
end

function Errors.BuildValidationFailure(errorKey: any, message: string, data: TMouseErrorData?): (string, string, TMouseErrorData?)
	return _BuildError(errorKey, message, data)
end

function Errors.BuildUnsupportedRuntime(reason: string?): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.UnsupportedRuntime, nil, {
		Reason = reason,
	})
end

function Errors.BuildMissingCamera(screenPoint: Vector2?, rayLength: number?): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.MissingCamera, nil, {
		ScreenPoint = screenPoint,
		RayLength = rayLength,
		Reason = "CameraProvider returned nil",
	})
end

function Errors.BuildServiceDestroyed(): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.MouseServiceDestroyed, nil, {
		Reason = "Manager is no longer usable",
	})
end

function Errors.BuildInvalidChannelName(channelName: any): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.InvalidChannelName, nil, {
		ChannelName = if type(channelName) == "string" then channelName else nil,
		Reason = "Channel name must be a non-empty string",
	})
end

function Errors.BuildSelectionTargetNotFound(channelName: string): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.SelectionTargetNotFound, nil, {
		ChannelName = channelName,
		Reason = "No selection target resolved from the current mouse request",
	})
end

function Errors.BuildHoverTargetNotFound(channelName: string): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.HoverTargetNotFound, nil, {
		ChannelName = channelName,
		Reason = "No hover target resolved from the current mouse request",
	})
end

function Errors.BuildDragWorldPointNotFound(channelName: string): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.DragWorldPointNotFound, nil, {
		ChannelName = channelName,
		Reason = "No world point resolved for drag session",
	})
end

function Errors.BuildMissingHoverSession(channelName: string, state: string?): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.MissingHoverSession, nil, {
		ChannelName = channelName,
		State = state,
		Reason = "Hover session is not active for this channel",
	})
end

function Errors.BuildDuplicateHoverSession(channelName: string, state: string?): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.DuplicateHoverSession, nil, {
		ChannelName = channelName,
		State = state,
		Reason = "Hover session is already active for this channel",
	})
end

function Errors.BuildIllegalHoverTransition(
	channelName: string,
	state: string?,
	reason: string
): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.IllegalHoverTransition, nil, {
		ChannelName = channelName,
		State = state,
		Reason = reason,
	})
end

function Errors.BuildMissingDragSession(channelName: string, state: string?): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.MissingDragSession, nil, {
		ChannelName = channelName,
		State = state,
		Reason = "Drag session is not active for this channel",
	})
end

function Errors.BuildDuplicateDragSession(channelName: string, state: string?): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.DuplicateDragSession, nil, {
		ChannelName = channelName,
		State = state,
		Reason = "Drag session is already active for this channel",
	})
end

function Errors.BuildIllegalDragTransition(
	channelName: string,
	state: string?,
	reason: string
): (string, string, TMouseErrorData?)
	return _BuildError(Enums.ErrorKey.IllegalDragTransition, nil, {
		ChannelName = channelName,
		State = state,
		Reason = reason,
	})
end

return table.freeze(Errors)
