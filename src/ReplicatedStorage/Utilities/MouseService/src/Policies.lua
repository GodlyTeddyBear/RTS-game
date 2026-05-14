--!strict

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Enums = require(script.Parent.Enums)
local Errors = require(script.Parent.Errors)
local Specs = require(script.Parent.Specs)

local Policies = {}

local function _RaiseValidationFailure(result: any)
	error(result.message, 3)
end

local function _AssertSatisfied(result: any)
	if not result.success then
		_RaiseValidationFailure(result)
	end
end

local function _BuildValidationErr(errorKey: any, message: string, data: any): Result.Err
	local errorType, errorMessage, errorData = Errors.BuildValidationFailure(errorKey, message, data)
	return Result.Err(errorType, errorMessage, errorData)
end

function Policies.CheckManagerConfig(config: any)
	_AssertSatisfied(Specs.HasValidManagerConfigSpec:IsSatisfiedBy({
		Config = config,
		CameraProvider = if config ~= nil then config.CameraProvider else nil,
		RayLength = if config ~= nil then config.RayLength else nil,
		ResolveTarget = if config ~= nil then config.ResolveTarget else nil,
		DragMode = nil,
		QueryOptions = if config ~= nil then config.QueryOptions else nil,
		SelectionOptions = if config ~= nil then config.SelectionOptions else nil,
		ProjectionPlane = if config ~= nil then config.ProjectionPlane else nil,
		BaseExclude = if config ~= nil then config.BaseExclude else nil,
		MirrorSelection = if config ~= nil then config.MirrorSelections else nil,
		MirrorHover = if config ~= nil then config.MirrorHovers else nil,
		MirrorPreviewSelection = nil,
		PreviewSelectionChannel = nil,
		Highlight = if config ~= nil then config.DefaultSelectionHighlight else nil,
		Radius = if config ~= nil then config.DefaultSelectionRadius else nil,
		HoverHighlight = if config ~= nil then config.DefaultHoverHighlight else nil,
		HoverRadius = if config ~= nil then config.DefaultHoverRadius else nil,
		MarqueeQueryOptions = nil,
		MarqueeSelectionOptions = nil,
		MarqueeMetadata = nil,
	}))
end

function Policies.AssertClientRuntime()
	_AssertSatisfied(Specs.HasClientRuntimeSpec:IsSatisfiedBy({
		IsClient = RunService:IsClient(),
	}))
end

function Policies.CheckRequest(request: any): Result.Result<boolean>
	local result = Specs.HasValidRequestShapeSpec:IsSatisfiedBy({
		Request = request,
		ScreenPoint = if request ~= nil then request.ScreenPoint else nil,
		CameraProvider = if request ~= nil then request.CameraProvider else nil,
		RayLength = if request ~= nil then request.RayLength else nil,
		ResolveTarget = if request ~= nil then request.ResolveTarget else nil,
		QueryOptions = if request ~= nil then request.QueryOptions else nil,
		SelectionOptions = if request ~= nil then request.SelectionOptions else nil,
		ProjectionPlane = if request ~= nil then request.ProjectionPlane else nil,
		BaseExclude = if request ~= nil then request.BaseExclude else nil,
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorKey = Enums.ErrorKey[result.type]
	return _BuildValidationErr(
		if errorKey ~= nil then errorKey else Enums.ErrorKey.InvalidRequest,
		result.message,
		{
			ScreenPoint = if request ~= nil then request.ScreenPoint else nil,
			RayLength = if request ~= nil then request.RayLength else nil,
			Reason = result.message,
		}
	)
end

function Policies.CheckSelectionRequest(request: any): Result.Result<boolean>
	local result = Specs.HasValidSelectionRequestSpec:IsSatisfiedBy({
		Request = request,
		ScreenPoint = if request ~= nil then request.ScreenPoint else nil,
		CameraProvider = if request ~= nil then request.CameraProvider else nil,
		RayLength = if request ~= nil then request.RayLength else nil,
		ResolveTarget = if request ~= nil then request.ResolveTarget else nil,
		QueryOptions = if request ~= nil then request.QueryOptions else nil,
		SelectionOptions = if request ~= nil then request.SelectionOptions else nil,
		ProjectionPlane = if request ~= nil then request.ProjectionPlane else nil,
		BaseExclude = if request ~= nil then request.BaseExclude else nil,
		Metadata = if request ~= nil then request.Metadata else nil,
		MirrorSelection = if request ~= nil then request.MirrorSelection else nil,
		Highlight = if request ~= nil then request.Highlight else nil,
		Radius = if request ~= nil then request.Radius else nil,
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorKey = Enums.ErrorKey[result.type]
	return _BuildValidationErr(
		if errorKey ~= nil then errorKey else Enums.ErrorKey.InvalidSelectionRequest,
		result.message,
		{
			ScreenPoint = if request ~= nil then request.ScreenPoint else nil,
			RayLength = if request ~= nil then request.RayLength else nil,
			Reason = result.message,
		}
	)
end

function Policies.CheckDragRequest(request: any): Result.Result<boolean>
	local result = Specs.HasValidDragRequestSpec:IsSatisfiedBy({
		Request = request,
		ScreenPoint = if request ~= nil then request.ScreenPoint else nil,
		CameraProvider = if request ~= nil then request.CameraProvider else nil,
		RayLength = if request ~= nil then request.RayLength else nil,
		ResolveTarget = if request ~= nil then request.ResolveTarget else nil,
		DragMode = if request ~= nil then request.DragMode else nil,
		QueryOptions = if request ~= nil then request.QueryOptions else nil,
		SelectionOptions = if request ~= nil then request.SelectionOptions else nil,
		ProjectionPlane = if request ~= nil then request.ProjectionPlane else nil,
		BaseExclude = if request ~= nil then request.BaseExclude else nil,
		Metadata = if request ~= nil then request.Metadata else nil,
		MirrorPreviewSelection = if request ~= nil then request.MirrorPreviewSelection else nil,
		PreviewSelectionChannel = if request ~= nil then request.PreviewSelectionChannel else nil,
		MarqueeQueryOptions = if request ~= nil then request.MarqueeQueryOptions else nil,
		MarqueeSelectionOptions = if request ~= nil then request.MarqueeSelectionOptions else nil,
		MarqueeMetadata = if request ~= nil then request.MarqueeMetadata else nil,
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorKey = Enums.ErrorKey[result.type]
	return _BuildValidationErr(
		if errorKey ~= nil then errorKey else Enums.ErrorKey.InvalidDragRequest,
		result.message,
		{
			ScreenPoint = if request ~= nil then request.ScreenPoint else nil,
			RayLength = if request ~= nil then request.RayLength else nil,
			Reason = result.message,
		}
	)
end

function Policies.CheckHoverRequest(request: any): Result.Result<boolean>
	local result = Specs.HasValidHoverRequestSpec:IsSatisfiedBy({
		Request = request,
		ScreenPoint = if request ~= nil then request.ScreenPoint else nil,
		CameraProvider = if request ~= nil then request.CameraProvider else nil,
		RayLength = if request ~= nil then request.RayLength else nil,
		ResolveTarget = if request ~= nil then request.ResolveTarget else nil,
		QueryOptions = if request ~= nil then request.QueryOptions else nil,
		SelectionOptions = if request ~= nil then request.SelectionOptions else nil,
		ProjectionPlane = if request ~= nil then request.ProjectionPlane else nil,
		BaseExclude = if request ~= nil then request.BaseExclude else nil,
		Metadata = if request ~= nil then request.Metadata else nil,
		MirrorHover = if request ~= nil then request.MirrorHover else nil,
		Highlight = if request ~= nil then request.Highlight else nil,
		Radius = if request ~= nil then request.Radius else nil,
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorKey = Enums.ErrorKey[result.type]
	return _BuildValidationErr(
		if errorKey ~= nil then errorKey else Enums.ErrorKey.InvalidHoverRequest,
		result.message,
		{
			ScreenPoint = if request ~= nil then request.ScreenPoint else nil,
			RayLength = if request ~= nil then request.RayLength else nil,
			Reason = result.message,
		}
	)
end

function Policies.CheckChannelName(channelName: any): Result.Result<string>
	local result = Specs.HasValidChannelNameSpec:IsSatisfiedBy({
		ChannelName = channelName,
	})
	if result.success and type(channelName) == "string" then
		return Result.Ok(channelName)
	end

	local errorType, message, data = Errors.BuildInvalidChannelName(channelName)
	return Result.Err(errorType, message, data)
end

function Policies.CheckClientRuntime(_request: any): Result.Result<boolean>
	local result = Specs.HasClientRuntimeSpec:IsSatisfiedBy({
		IsClient = RunService:IsClient(),
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorType, message, data = Errors.BuildUnsupportedRuntime(result.message)
	return Result.Err(errorType, message, data)
end

function Policies.CheckCamera(camera: Camera?, request: any): Result.Result<Camera>
	local result = Specs.HasCameraSpec:IsSatisfiedBy({
		Camera = camera,
	})
	if result.success and camera ~= nil then
		return Result.Ok(camera)
	end

	local errorType, message, data = Errors.BuildMissingCamera(
		if request ~= nil then request.ScreenPoint else nil,
		if request ~= nil then request.RayLength else nil
	)
	return Result.Err(errorType, message, data)
end

function Policies.CheckServiceAlive(service: any): Result.Result<boolean>
	local result = Specs.HasAliveServiceSpec:IsSatisfiedBy({
		IsDestroyed = service._isDestroyed == true,
	})
	if result.success then
		return Result.Ok(true)
	end

	local errorType, message, data = Errors.BuildServiceDestroyed()
	return Result.Err(errorType, message, data)
end

function Policies.CheckDragTransition(channelName: string, currentState: any, actionName: string): Result.Result<boolean>
	local hasSession = currentState ~= nil
	local result = if actionName == "Begin"
		then Specs.CanBeginDragSpec:IsSatisfiedBy({
			HasSession = hasSession,
		})
		else Specs.CanOperateOnDragSpec:IsSatisfiedBy({
			HasSession = hasSession,
		})

	if result.success then
		return Result.Ok(true)
	end

	if actionName == "Begin" then
		local errorType, message, data = Errors.BuildDuplicateDragSession(
			channelName,
			if currentState ~= nil and currentState.State ~= nil then currentState.State.Name else nil
		)
		return Result.Err(errorType, message, data)
	end

	local errorType, message, data = Errors.BuildMissingDragSession(
		channelName,
		if currentState ~= nil and currentState.State ~= nil then currentState.State.Name else nil
	)
	return Result.Err(errorType, message, data)
end

function Policies.CheckHoverTransition(channelName: string, currentState: any, actionName: string): Result.Result<boolean>
	local hasSession = currentState ~= nil
	local result = if actionName == "Begin"
		then Specs.CanBeginHoverSpec:IsSatisfiedBy({
			HasSession = hasSession,
		})
		else Specs.CanOperateOnHoverSpec:IsSatisfiedBy({
			HasSession = hasSession,
		})

	if result.success then
		return Result.Ok(true)
	end

	if actionName == "Begin" then
		local errorType, message, data = Errors.BuildDuplicateHoverSession(
			channelName,
			if currentState ~= nil and currentState.Snapshot ~= nil and currentState.Snapshot.State ~= nil
				then currentState.Snapshot.State.Name
				else nil
		)
		return Result.Err(errorType, message, data)
	end

	local errorType, message, data = Errors.BuildMissingHoverSession(
		channelName,
		if currentState ~= nil and currentState.Snapshot ~= nil and currentState.Snapshot.State ~= nil
			then currentState.Snapshot.State.Name
			else nil
	)
	return Result.Err(errorType, message, data)
end

return table.freeze(Policies)
