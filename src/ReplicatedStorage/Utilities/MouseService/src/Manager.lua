--!strict

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Option = require(ReplicatedStorage.Utilities.Option)
local Result = require(ReplicatedStorage.Utilities.Result)
local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)

local Drag = require(script.Parent.Drag)
local Enums = require(script.Parent.Enums)
local Hover = require(script.Parent.Hover)
local Options = require(script.Parent.Options)
local Policies = require(script.Parent.Policies)
local Resolver = require(script.Parent.Resolver)
local Selection = require(script.Parent.Selection)
local Signals = require(script.Parent.Signals)
local Types = require(script.Parent.Types)

type TMouseDragRequest = Types.TMouseDragRequest
type TMouseDragSnapshot = Types.TMouseDragSnapshot
type TMarqueeRequest = Types.TMarqueeRequest
type THoverRequest = Types.THoverRequest
type THoverSnapshot = Types.THoverSnapshot
type TMouseManager = Types.TMouseManager
type TMouseManagerConfig = Types.TMouseManagerConfig
type TMouseRequest = Types.TMouseRequest
type TMouseSelectionRequest = Types.TMouseSelectionRequest
type TMouseSelectionSnapshot = Types.TMouseSelectionSnapshot
type TMouseSnapshot = Types.TMouseSnapshot

local CAMERA_INVALIDATION_KEY = "CurrentCameraInvalidation"
local SNAPSHOT_CLEAR_KEY = "LastSnapshotClear"
local SELECTION_CHANGED_SIGNAL_KEY = "SelectionChanged"
local SELECTION_CLEARED_SIGNAL_KEY = "SelectionCleared"
local HOVER_CHANGED_SIGNAL_KEY = "HoverChanged"
local HOVER_CLEARED_SIGNAL_KEY = "HoverCleared"
local MARQUEE_PREVIEW_CHANGED_SIGNAL_KEY = "MarqueePreviewChanged"
local DRAG_STARTED_SIGNAL_KEY = "DragStarted"
local DRAG_UPDATED_SIGNAL_KEY = "DragUpdated"
local DRAG_ENDED_SIGNAL_KEY = "DragEnded"
local DRAG_CANCELLED_SIGNAL_KEY = "DragCancelled"

local Manager = {}
Manager.__index = Manager

function Manager.new(config: TMouseManagerConfig?): TMouseManager
	Policies.AssertClientRuntime()
	Policies.CheckManagerConfig(config)

	local self = setmetatable({}, Manager) :: any
	self._config = Options.CreateConfig(config)
	self._stash = StashPlus.new()
	self._isDestroyed = false
	self._lastSnapshotOption = Option.None
	self._selectionManager = nil
	self._hoverSelectionManager = nil
	self._dragPreviewSelectionManager = nil
	self._hoverLoopConnection = nil
	self._selectionStateByChannel = {}
	self._hoverStateByChannel = {}
	self._dragStateByChannel = {}
	self.SelectionChanged = Signals.Create(self._stash, SELECTION_CHANGED_SIGNAL_KEY)
	self.SelectionCleared = Signals.Create(self._stash, SELECTION_CLEARED_SIGNAL_KEY)
	self.HoverChanged = Signals.Create(self._stash, HOVER_CHANGED_SIGNAL_KEY)
	self.HoverCleared = Signals.Create(self._stash, HOVER_CLEARED_SIGNAL_KEY)
	self.MarqueePreviewChanged = Signals.Create(self._stash, MARQUEE_PREVIEW_CHANGED_SIGNAL_KEY)
	self.DragStarted = Signals.Create(self._stash, DRAG_STARTED_SIGNAL_KEY)
	self.DragUpdated = Signals.Create(self._stash, DRAG_UPDATED_SIGNAL_KEY)
	self.DragEnded = Signals.Create(self._stash, DRAG_ENDED_SIGNAL_KEY)
	self.DragCancelled = Signals.Create(self._stash, DRAG_CANCELLED_SIGNAL_KEY)

	-- Invalidate cached snapshots when the active camera changes
	self._stash:AddConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:ClearLastSnapshot()
	end), {
		Key = CAMERA_INVALIDATION_KEY,
		Label = CAMERA_INVALIDATION_KEY,
	})

	-- Clear cached state during destruction
	self._stash:AddCallback(SNAPSHOT_CLEAR_KEY, function()
		self._lastSnapshotOption = Option.None
	end, {
		Key = SNAPSHOT_CLEAR_KEY,
		Label = SNAPSHOT_CLEAR_KEY,
	})

	return self
end

function Manager:ResolveSnapshot(request: TMouseRequest?): Result.Result<TMouseSnapshot>
	-- Validate the manager and request before touching client services
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local runtimeResult = Policies.CheckClientRuntime(request)
	if not runtimeResult.success then
		return runtimeResult
	end

	local requestResult = Policies.CheckRequest(request)
	if not requestResult.success then
		return requestResult
	end

	local resolvedRequest = Options.ResolveRequest(self._config, request)
	local source = if resolvedRequest.ScreenPoint ~= nil
		then Enums.SnapshotSource.ScreenPoint
		else Enums.SnapshotSource.CurrentMouse
	local screenPoint = if resolvedRequest.ScreenPoint ~= nil
		then resolvedRequest.ScreenPoint
		else UserInputService:GetMouseLocation()

	-- Resolve the camera after request overrides are applied
	local cameraResult = Policies.CheckCamera(Resolver.ResolveCamera(resolvedRequest), resolvedRequest)
	if not cameraResult.success then
		return cameraResult
	end

	-- Build and cache the final snapshot
	local snapshot = Resolver.ResolveSnapshot(source, screenPoint, cameraResult.value, resolvedRequest)
	self._lastSnapshotOption = Option.Some(snapshot)
	return Result.Ok(snapshot)
end

function Manager:ResolveWorldPoint(request: TMouseRequest?): Result.Result<Vector3?>
	return self:ResolveSnapshot(request):andThen(function(snapshot: TMouseSnapshot)
		return Result.Ok(snapshot.WorldPoint)
	end)
end

function Manager:ResolveTarget(request: TMouseRequest?): Result.Result<any>
	return self:ResolveSnapshot(request):andThen(function(snapshot: TMouseSnapshot)
		return Result.Ok(snapshot.ResolvedTarget)
	end)
end

function Manager:SetSelection(channelName: string, request: TMouseSelectionRequest?): Result.Result<TMouseSelectionSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Selection.SetSelection(self, channelName, request)
end

function Manager:SetSelectionFromCurrentMouse(
	channelName: string,
	request: TMouseSelectionRequest?
): Result.Result<TMouseSelectionSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Selection.SetSelectionFromCurrentMouse(self, channelName, request)
end

function Manager:ClearSelection(channelName: string): Result.Result<TMouseSelectionSnapshot?>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Selection.ClearSelection(self, channelName)
end

function Manager:ClearAllSelections()
	if not Policies.CheckServiceAlive(self).success then
		return
	end

	Selection.ClearAllSelections(self)
end

function Manager:GetSelectionSnapshot(channelName: string): TMouseSelectionSnapshot?
	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return nil
	end

	return self._selectionStateByChannel[channelName]
end

function Manager:GetSelectionTarget(channelName: string): any
	local selectionSnapshot = self:GetSelectionSnapshot(channelName)
	if selectionSnapshot == nil then
		return nil
	end

	return selectionSnapshot.Target
end

function Manager:HasSelection(channelName: string): boolean
	return self:GetSelectionSnapshot(channelName) ~= nil
end

function Manager:BeginHover(channelName: string, request: THoverRequest?): Result.Result<THoverSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Hover.BeginHover(self, channelName, request)
end

function Manager:RefreshHover(channelName: string, request: THoverRequest?): Result.Result<THoverSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Hover.RefreshHover(self, channelName, request)
end

function Manager:EndHover(channelName: string): Result.Result<THoverSnapshot?>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Hover.EndHover(self, channelName)
end

function Manager:GetHoverSnapshot(channelName: string): THoverSnapshot?
	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return nil
	end

	local hoverSession = self._hoverStateByChannel[channelName]
	if hoverSession == nil then
		return nil
	end

	return hoverSession.Snapshot
end

function Manager:GetHoverTarget(channelName: string): any
	local hoverSnapshot = self:GetHoverSnapshot(channelName)
	if hoverSnapshot == nil then
		return nil
	end

	return hoverSnapshot.Target
end

function Manager:IsHovering(channelName: string): boolean
	return self:GetHoverSnapshot(channelName) ~= nil
end

function Manager:BeginDrag(channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Drag.BeginDrag(self, channelName, request)
end

function Manager:BeginMarquee(channelName: string, request: TMarqueeRequest?): Result.Result<TMouseDragSnapshot>
	local marqueeRequest = Options.CreateDragRequest(request)
	marqueeRequest.DragMode = Enums.DragMode.Marquee
	return self:BeginDrag(channelName, marqueeRequest)
end

function Manager:UpdateDrag(channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Drag.UpdateDrag(self, channelName, request)
end

function Manager:UpdateMarquee(channelName: string, request: TMarqueeRequest?): Result.Result<TMouseDragSnapshot>
	local marqueeRequest = Options.CreateDragRequest(request)
	marqueeRequest.DragMode = Enums.DragMode.Marquee
	return self:UpdateDrag(channelName, marqueeRequest)
end

function Manager:EndDrag(channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Drag.EndDrag(self, channelName, request)
end

function Manager:EndMarquee(channelName: string, request: TMarqueeRequest?): Result.Result<TMouseDragSnapshot>
	local marqueeRequest = if request ~= nil then Options.CreateDragRequest(request) else nil
	if marqueeRequest ~= nil then
		marqueeRequest.DragMode = Enums.DragMode.Marquee
	end
	return self:EndDrag(channelName, marqueeRequest)
end

function Manager:CancelDrag(channelName: string): Result.Result<TMouseDragSnapshot>
	local aliveResult = Policies.CheckServiceAlive(self)
	if not aliveResult.success then
		return aliveResult
	end

	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return channelResult
	end

	return Drag.CancelDrag(self, channelName)
end

function Manager:CancelMarquee(channelName: string): Result.Result<TMouseDragSnapshot>
	return self:CancelDrag(channelName)
end

function Manager:GetDragSnapshot(channelName: string): TMouseDragSnapshot?
	local channelResult = Policies.CheckChannelName(channelName)
	if not channelResult.success then
		return nil
	end

	local dragSession = self._dragStateByChannel[channelName]
	if dragSession == nil then
		return nil
	end

	return dragSession.Snapshot
end

function Manager:IsDragging(channelName: string): boolean
	local dragSnapshot = self:GetDragSnapshot(channelName)
	return dragSnapshot ~= nil and dragSnapshot.State == Enums.DragState.Active
end

function Manager:GetMarqueeSnapshot(channelName: string): TMouseDragSnapshot?
	local dragSnapshot = self:GetDragSnapshot(channelName)
	if dragSnapshot == nil or dragSnapshot.Mode ~= Enums.DragMode.Marquee then
		return nil
	end

	return dragSnapshot
end

function Manager:IsMarqueeActive(channelName: string): boolean
	local marqueeSnapshot = self:GetMarqueeSnapshot(channelName)
	return marqueeSnapshot ~= nil and marqueeSnapshot.State == Enums.DragState.Active
end

function Manager:GetLastSnapshot(): TMouseSnapshot?
	return self._lastSnapshotOption:UnwrapOr(nil)
end

function Manager:ClearLastSnapshot()
	self._lastSnapshotOption = Option.None
end

function Manager:Destroy()
	if self._isDestroyed then
		return
	end

	self:ClearAllSelections()
	Hover.ClearAllHovers(self)
	self._dragStateByChannel = {}
	self._hoverStateByChannel = {}
	self._selectionStateByChannel = {}
	if self._hoverLoopConnection ~= nil then
		self._hoverLoopConnection:Disconnect()
		self._hoverLoopConnection = nil
	end
	self._isDestroyed = true
	self._stash:Destroy()
end

return table.freeze(Manager)
