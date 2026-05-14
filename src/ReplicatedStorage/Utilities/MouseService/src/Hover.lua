--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)

local Enums = require(script.Parent.Enums)
local Errors = require(script.Parent.Errors)
local Options = require(script.Parent.Options)
local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)

type THoverRequest = Types.THoverRequest
type THoverSnapshot = Types.THoverSnapshot
type TResolvedHoverRequest = Types.TResolvedHoverRequest
type TResolvedHoverResult = {
	ResolvedRequest: TResolvedHoverRequest,
	MouseSnapshot: Types.TMouseSnapshot,
}
type THoverSession = {
	Request: TResolvedHoverRequest,
	Snapshot: THoverSnapshot,
}

local HOVER_SCOPE_PREFIX = "hover:"
local HOVER_VISUAL_CHANNEL_PREFIX = "__mouse_hover__:"
local HOVER_VISUAL_CLEAR_KEY = "HoverVisualClear"
local HOVER_SELECTION_MANAGER_KEY = "HoverSelectionManager"

local Hover = {}

local function _BuildScopeKey(channelName: string): string
	return HOVER_SCOPE_PREFIX .. channelName
end

local function _BuildVisualChannelName(channelName: string): string
	return HOVER_VISUAL_CHANNEL_PREFIX .. channelName
end

local function _GetOrCreateHoverSelectionManager(manager: any): any
	if manager._hoverSelectionManager ~= nil then
		return manager._hoverSelectionManager
	end

	local selectionManager = SelectionPlus.new({
		Parent = manager._config.SelectionParent,
		Name = "MouseServiceHover",
		DefaultHighlight = manager._config.DefaultHoverHighlight,
		DefaultRadius = manager._config.DefaultHoverRadius,
	})
	manager._hoverSelectionManager = selectionManager
	manager._stash:Add(selectionManager, {
		CleanupMethod = "Destroy",
		Key = HOVER_SELECTION_MANAGER_KEY,
		Label = HOVER_SELECTION_MANAGER_KEY,
	})
	return selectionManager
end

local function _ShouldMirrorHover(manager: any, resolvedRequest: TResolvedHoverRequest): boolean
	if resolvedRequest.MirrorHover then
		return true
	end

	return resolvedRequest.Highlight ~= nil or resolvedRequest.Radius ~= nil or manager._config.MirrorHovers == true
end

local function _CreateHoverSnapshot(
	channelName: string,
	resolvedRequest: TResolvedHoverRequest,
	mouseSnapshot: Types.TMouseSnapshot,
	mirrored: boolean
): THoverSnapshot
	return table.freeze({
		Channel = channelName,
		State = Enums.HoverState.Active,
		MouseSnapshot = mouseSnapshot,
		Target = mouseSnapshot.ResolvedTarget :: SelectionPlus.TResolvedSelectionTarget,
		Metadata = resolvedRequest.Metadata,
		Mirrored = mirrored,
	})
end

local function _ResolveMouseHover(
	manager: any,
	channelName: string,
	request: THoverRequest?
): Result.Result<TResolvedHoverResult>
	local requestResult = Policies.CheckHoverRequest(request)
	if not requestResult.success then
		return requestResult
	end

	local resolvedRequest = Options.ResolveHoverRequest(manager._config, request)
	local mouseSnapshotResult = manager:ResolveSnapshot(resolvedRequest)
	if not mouseSnapshotResult.success then
		return mouseSnapshotResult
	end

	local mouseSnapshot = mouseSnapshotResult.value
	if mouseSnapshot.ResolvedTarget == nil then
		local errorType, message, data = Errors.BuildHoverTargetNotFound(channelName)
		return Result.Err(errorType, message, data)
	end

	return Result.Ok({
		ResolvedRequest = resolvedRequest,
		MouseSnapshot = mouseSnapshot,
	})
end

local function _IsSameHit(left: RaycastResult?, right: RaycastResult?): boolean
	if left == nil or right == nil then
		return left == right
	end

	return left.Instance == right.Instance and left.Position == right.Position and left.Normal == right.Normal
end

local function _IsSameTarget(
	left: SelectionPlus.TResolvedSelectionTarget,
	right: SelectionPlus.TResolvedSelectionTarget
): boolean
	return left.Root == right.Root
		and left.Adornee == right.Adornee
		and left.Model == right.Model
		and left.WorldPosition == right.WorldPosition
		and left.BoundsCFrame == right.BoundsCFrame
		and left.BoundsSize == right.BoundsSize
		and _IsSameHit(left.Hit, right.Hit)
end

local function _HasHoverChanged(previousSnapshot: THoverSnapshot?, nextSnapshot: THoverSnapshot): boolean
	if previousSnapshot == nil then
		return true
	end

	local previousMouseSnapshot = previousSnapshot.MouseSnapshot
	local nextMouseSnapshot = nextSnapshot.MouseSnapshot

	return previousSnapshot.Mirrored ~= nextSnapshot.Mirrored
		or previousSnapshot.Metadata ~= nextSnapshot.Metadata
		or previousSnapshot.State ~= nextSnapshot.State
		or previousMouseSnapshot.ScreenPoint ~= nextMouseSnapshot.ScreenPoint
		or previousMouseSnapshot.WorldPoint ~= nextMouseSnapshot.WorldPoint
		or previousMouseSnapshot.ProjectedWorldPoint ~= nextMouseSnapshot.ProjectedWorldPoint
		or previousMouseSnapshot.RayOrigin ~= nextMouseSnapshot.RayOrigin
		or previousMouseSnapshot.RayDirection ~= nextMouseSnapshot.RayDirection
		or previousMouseSnapshot.RayLength ~= nextMouseSnapshot.RayLength
		or previousMouseSnapshot.Camera ~= nextMouseSnapshot.Camera
		or not _IsSameHit(previousMouseSnapshot.Hit, nextMouseSnapshot.Hit)
		or not _IsSameTarget(previousSnapshot.Target, nextSnapshot.Target)
end

local function _StopHoverLoop(manager: any)
	if manager._hoverLoopConnection == nil then
		return
	end

	manager._hoverLoopConnection:Disconnect()
	manager._hoverLoopConnection = nil
end

local function _HasActiveHoverSessions(manager: any): boolean
	return next(manager._hoverStateByChannel) ~= nil
end

local function _ClearHoverSession(
	manager: any,
	channelName: string,
	suppressSignal: boolean?
): THoverSnapshot?
	local session = manager._hoverStateByChannel[channelName] :: THoverSession?
	if session == nil then
		if manager._stash:HasScope(_BuildScopeKey(channelName)) then
			manager._stash:DestroyScope(_BuildScopeKey(channelName))
		end
		if not _HasActiveHoverSessions(manager) then
			_StopHoverLoop(manager)
		end
		return nil
	end

	local previousSnapshot = session.Snapshot
	manager._hoverStateByChannel[channelName] = nil
	if manager._stash:HasScope(_BuildScopeKey(channelName)) then
		manager._stash:DestroyScope(_BuildScopeKey(channelName))
	end
	if not _HasActiveHoverSessions(manager) then
		_StopHoverLoop(manager)
	end

	if not suppressSignal then
		manager.HoverCleared:Fire(channelName, previousSnapshot)
	end

	return previousSnapshot
end

local function _ApplyHoverVisualState(
	manager: any,
	channelName: string,
	resolvedRequest: TResolvedHoverRequest,
	mouseSnapshot: Types.TMouseSnapshot
): boolean
	local visualChannelName = _BuildVisualChannelName(channelName)
	local shouldMirror = _ShouldMirrorHover(manager, resolvedRequest)
	if not shouldMirror then
		if manager._hoverSelectionManager ~= nil then
			manager._hoverSelectionManager:Clear(visualChannelName)
		end
		return false
	end

	local selectionManager = _GetOrCreateHoverSelectionManager(manager)
	selectionManager:SetSelection(visualChannelName, {
		Target = mouseSnapshot.ResolvedTarget,
		Highlight = resolvedRequest.Highlight,
		Radius = resolvedRequest.Radius,
		Metadata = resolvedRequest.Metadata,
	})
	return true
end

local _RefreshHoverSession

local function _EnsureHoverLoop(manager: any)
	if manager._hoverLoopConnection ~= nil then
		return
	end

	manager._hoverLoopConnection = RunService.RenderStepped:Connect(function()
		local channelNames = {}
		for channelName in pairs(manager._hoverStateByChannel) do
			channelNames[#channelNames + 1] = channelName
		end

		if #channelNames == 0 then
			_StopHoverLoop(manager)
			return
		end

		for _, channelName in ipairs(channelNames) do
			if manager._hoverStateByChannel[channelName] ~= nil then
				_RefreshHoverSession(manager, channelName, nil, true)
			end
		end
	end)
end

_RefreshHoverSession = function(
	manager: any,
	channelName: string,
	request: THoverRequest?,
	_isLoopRefresh: boolean?
): Result.Result<THoverSnapshot>
	local session = manager._hoverStateByChannel[channelName] :: THoverSession?
	local transitionResult = Policies.CheckHoverTransition(channelName, session, "Refresh")
	if not transitionResult.success then
		return transitionResult
	end

	local requestToUse = if request ~= nil then request else session.Request
	local resolvedHoverResult = _ResolveMouseHover(manager, channelName, requestToUse)
	if not resolvedHoverResult.success then
		if resolvedHoverResult.type == Enums.ErrorKey.HoverTargetNotFound.Name then
			_ClearHoverSession(manager, channelName)
		end
		return resolvedHoverResult
	end

	local resolvedHover = resolvedHoverResult.value
	local previousSnapshot = session.Snapshot
	local mirrored = _ApplyHoverVisualState(manager, channelName, resolvedHover.ResolvedRequest, resolvedHover.MouseSnapshot)
	local hoverSnapshot = _CreateHoverSnapshot(channelName, resolvedHover.ResolvedRequest, resolvedHover.MouseSnapshot, mirrored)

	session.Request = resolvedHover.ResolvedRequest
	session.Snapshot = hoverSnapshot
	manager._hoverStateByChannel[channelName] = session

	if _HasHoverChanged(previousSnapshot, hoverSnapshot) then
		manager.HoverChanged:Fire(channelName, hoverSnapshot, previousSnapshot)
	end

	return Result.Ok(hoverSnapshot)
end

function Hover.BeginHover(manager: any, channelName: string, request: THoverRequest?): Result.Result<THoverSnapshot>
	local transitionResult = Policies.CheckHoverTransition(channelName, manager._hoverStateByChannel[channelName], "Begin")
	if not transitionResult.success then
		return transitionResult
	end

	local resolvedHoverResult = _ResolveMouseHover(manager, channelName, request)
	if not resolvedHoverResult.success then
		return resolvedHoverResult
	end

	local scope = manager._stash:Scope(_BuildScopeKey(channelName))
	scope:AddCallback(HOVER_VISUAL_CLEAR_KEY, function()
		if manager._hoverSelectionManager ~= nil then
			manager._hoverSelectionManager:Clear(_BuildVisualChannelName(channelName))
		end
	end, {
		Key = HOVER_VISUAL_CLEAR_KEY,
		Label = HOVER_VISUAL_CLEAR_KEY,
	})

	local resolvedHover = resolvedHoverResult.value
	local mirrored = _ApplyHoverVisualState(manager, channelName, resolvedHover.ResolvedRequest, resolvedHover.MouseSnapshot)
	local hoverSnapshot = _CreateHoverSnapshot(channelName, resolvedHover.ResolvedRequest, resolvedHover.MouseSnapshot, mirrored)
	local session: THoverSession = {
		Request = resolvedHover.ResolvedRequest,
		Snapshot = hoverSnapshot,
	}

	manager._hoverStateByChannel[channelName] = session
	_EnsureHoverLoop(manager)
	manager.HoverChanged:Fire(channelName, hoverSnapshot, nil)
	return Result.Ok(hoverSnapshot)
end

function Hover.RefreshHover(manager: any, channelName: string, request: THoverRequest?): Result.Result<THoverSnapshot>
	return _RefreshHoverSession(manager, channelName, request)
end

function Hover.EndHover(manager: any, channelName: string): Result.Result<THoverSnapshot?>
	local transitionResult = Policies.CheckHoverTransition(channelName, manager._hoverStateByChannel[channelName], "End")
	if not transitionResult.success then
		return transitionResult
	end

	return Result.Ok(_ClearHoverSession(manager, channelName))
end

function Hover.ClearAllHovers(manager: any)
	local channelNames = {}
	for channelName in pairs(manager._hoverStateByChannel) do
		channelNames[#channelNames + 1] = channelName
	end

	for _, channelName in ipairs(channelNames) do
		_ClearHoverSession(manager, channelName)
	end

	_StopHoverLoop(manager)
end

return table.freeze(Hover)
