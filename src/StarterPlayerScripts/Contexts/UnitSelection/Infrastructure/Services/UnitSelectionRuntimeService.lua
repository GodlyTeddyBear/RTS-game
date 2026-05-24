--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local MouseService = require(ReplicatedStorage.Utilities.MouseService)
local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)
local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)
local UnitSelectionTypes = require(ReplicatedStorage.Contexts.UnitSelection.Types.UnitSelectionTypes)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

local GESTURE_CHANNEL = "UnitSelectionInput"
local MARQUEE_CHANNEL = "UnitSelectionMarquee"
local FINAL_SELECTION_CHANNEL = "UnitSelectionFinal"
local MARQUEE_HOLD_DURATION = 0.15
local DRAG_START_THRESHOLD = 8
local SINGLE_SELECTION_MAX_MOVEMENT = 6

local FINAL_SELECTION_HIGHLIGHT = table.freeze({
	FillColor = Color3.fromRGB(255, 221, 87),
	OutlineColor = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.75,
	OutlineTransparency = 0,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
})

local PREVIEW_SELECTION_HIGHLIGHT = table.freeze({
	FillColor = Color3.fromRGB(255, 221, 87),
	OutlineColor = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.88,
	OutlineTransparency = 0.25,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
})

local UnitSelectionRuntimeService = {}
UnitSelectionRuntimeService.__index = UnitSelectionRuntimeService

function UnitSelectionRuntimeService.new()
	local self = setmetatable({}, UnitSelectionRuntimeService)
	self._stash = StashPlus.new()
	self._mouseService = MouseService.new({
		DefaultEnabledButtons = { MouseService.MouseButton.Left },
		DefaultSelectionHighlight = PREVIEW_SELECTION_HIGHLIGHT,
		HoldDuration = MARQUEE_HOLD_DURATION,
		DragStartThreshold = DRAG_START_THRESHOLD,
		ClickMaxMovement = SINGLE_SELECTION_MAX_MOVEMENT,
	})
	self._selectionManager = SelectionPlus.new({
		Name = "UnitSelectionFinalSelection",
		DefaultHighlight = FINAL_SELECTION_HIGHLIGHT,
	})
	self._marqueeLoopConnection = nil :: RBXScriptConnection?
	self._isMarqueeActive = false
	self._isSelectionEnabled = true
	self._isHoldGateArmed = false
	self._hasDragThresholdReached = false
	self.SingleSelectionRequested = GoodSignal.new()
	self.MarqueePreviewChanged = GoodSignal.new()
	self.MarqueeSelectionRequested = GoodSignal.new()
	self.MarqueeCancelled = GoodSignal.new()
	self.SelectionInvalidated = GoodSignal.new()
	return self
end

function UnitSelectionRuntimeService:Start()
	self:_ConnectSignals()

	local gestureResult = self._mouseService:BeginGesture(GESTURE_CHANNEL, {
		EnabledButtons = { MouseService.MouseButton.Left },
		HoldDuration = MARQUEE_HOLD_DURATION,
		DragStartThreshold = DRAG_START_THRESHOLD,
		ClickMaxMovement = SINGLE_SELECTION_MAX_MOVEMENT,
	})
	if not gestureResult.success then
		error(
			string.format(
				"UnitSelectionRuntimeService failed to start gesture session: [%s] %s",
				tostring(gestureResult.type),
				tostring(gestureResult.message)
			)
		)
	end
end

function UnitSelectionRuntimeService:ApplySelectionRecords(records: { TSelectableUnitRecord })
	if #records == 0 then
		self:ClearSelection()
		return
	end

	local targets = table.create(#records)
	for _, record in ipairs(records) do
		targets[#targets + 1] = record.Target
	end

	self._selectionManager:SetSelectionSet(FINAL_SELECTION_CHANNEL, {
		Targets = targets,
		Highlight = FINAL_SELECTION_HIGHLIGHT,
	})
end

function UnitSelectionRuntimeService:ClearSelection()
	self._selectionManager:Clear(FINAL_SELECTION_CHANNEL)
end

function UnitSelectionRuntimeService:SetSelectionEnabled(isEnabled: boolean)
	self._isSelectionEnabled = isEnabled

	if isEnabled then
		return
	end

	if self._isMarqueeActive then
		self:_CancelMarquee()
	end

	self:_ResetMarqueeGateState()
end

function UnitSelectionRuntimeService:GetSelectionSnapshot()
	return self._selectionManager:GetSnapshot(FINAL_SELECTION_CHANNEL)
end

function UnitSelectionRuntimeService:Destroy()
	self:_StopMarqueeLoop()
	self._mouseService:EndGesture(GESTURE_CHANNEL)
	self._mouseService:Destroy()
	self._selectionManager:Destroy()
	self.SingleSelectionRequested:DisconnectAll()
	self.MarqueePreviewChanged:DisconnectAll()
	self.MarqueeSelectionRequested:DisconnectAll()
	self.MarqueeCancelled:DisconnectAll()
	self.SelectionInvalidated:DisconnectAll()
	self._stash:Destroy()
end

function UnitSelectionRuntimeService:_ConnectSignals()
	self._stash:AddConnection(self._mouseService.GesturePressed:Connect(function(channelName: string, event: any, _snapshot: any)
		if channelName ~= GESTURE_CHANNEL or event.Button ~= MouseService.MouseButton.Left or not self._isSelectionEnabled then
			return
		end

		self:_ResetMarqueeGateState()
	end))

	self._stash:AddConnection(self._mouseService.GestureHeld:Connect(function(channelName: string, event: any, _snapshot: any)
		if channelName ~= GESTURE_CHANNEL or event.Button ~= MouseService.MouseButton.Left or self._isMarqueeActive or not self._isSelectionEnabled then
			return
		end

		self._isHoldGateArmed = true
		self:_TryBeginMarquee()
	end))

	self._stash:AddConnection(self._mouseService.GestureDragThresholdReached:Connect(function(channelName: string, event: any, _snapshot: any)
		if channelName ~= GESTURE_CHANNEL or event.Button ~= MouseService.MouseButton.Left or self._isMarqueeActive or not self._isSelectionEnabled then
			return
		end

		self._hasDragThresholdReached = true
		self:_TryBeginMarquee()
	end))

	self._stash:AddConnection(self._mouseService.GestureReleased:Connect(function(channelName: string, event: any, _snapshot: any)
		if channelName ~= GESTURE_CHANNEL or event.Button ~= MouseService.MouseButton.Left then
			return
		end

		if not self._isSelectionEnabled then
			self:_ResetMarqueeGateState()
			return
		end

		if self._isMarqueeActive then
			self:_EndMarquee()
			return
		end

		if self:_ShouldSelectOnRelease(event) then
			self.SingleSelectionRequested:Fire(event.ResolvedTarget)
		end

		if not self._isMarqueeActive then
			self:_ResetMarqueeGateState()
		end
	end))

	self._stash:AddConnection(self._mouseService.MarqueePreviewChanged:Connect(function(channelName: string, snapshot: any, _previousSnapshot: any)
		if channelName ~= MARQUEE_CHANNEL or not self._isSelectionEnabled then
			return
		end

		self.MarqueePreviewChanged:Fire(snapshot)
	end))

	self._stash:AddConnection(self._selectionManager.SelectionInvalidated:Connect(function(channelName: string, previousSnapshot: any, _reason: any)
		if channelName ~= FINAL_SELECTION_CHANNEL then
			return
		end

		self.SelectionInvalidated:Fire(previousSnapshot)
	end))
end

function UnitSelectionRuntimeService:_ShouldSelectOnRelease(event: any): boolean
	if event.ResolvedTarget == nil then
		return true
	end

	return event.ScreenDelta.Magnitude <= SINGLE_SELECTION_MAX_MOVEMENT
end

function UnitSelectionRuntimeService:_TryBeginMarquee()
	if self._isMarqueeActive then
		return
	end

	if not self._isHoldGateArmed or not self._hasDragThresholdReached then
		return
	end

	self:_BeginMarquee()
end

function UnitSelectionRuntimeService:_BeginMarquee()
	local result = self._mouseService:BeginMarquee(MARQUEE_CHANNEL, {
		MirrorPreviewSelection = true,
		PreviewSelectionChannel = FINAL_SELECTION_CHANNEL,
	})
	if not result.success then
		return
	end

	self._isMarqueeActive = true
	self:_ResetMarqueeGateState()
	self:_StartMarqueeLoop()
end

function UnitSelectionRuntimeService:_EndMarquee()
	local result = self._mouseService:EndMarquee(MARQUEE_CHANNEL)
	self:_StopMarqueeLoop()
	self._isMarqueeActive = false
	self:_ResetMarqueeGateState()

	if not result.success then
		self.MarqueeCancelled:Fire()
		return
	end

	local snapshot = result.value
	self.MarqueePreviewChanged:Fire(snapshot)
	self.MarqueeSelectionRequested:Fire(snapshot.PreviewTargets)
end

function UnitSelectionRuntimeService:_StartMarqueeLoop()
	if self._marqueeLoopConnection ~= nil then
		return
	end

	self._marqueeLoopConnection = RunService.RenderStepped:Connect(function()
		if not self._isMarqueeActive then
			return
		end

		local result = self._mouseService:UpdateMarquee(MARQUEE_CHANNEL)
		if not result.success then
			self:_CancelMarquee()
		end
	end)
end

function UnitSelectionRuntimeService:_StopMarqueeLoop()
	if self._marqueeLoopConnection ~= nil then
		self._marqueeLoopConnection:Disconnect()
		self._marqueeLoopConnection = nil
	end
end

function UnitSelectionRuntimeService:_CancelMarquee()
	self._mouseService:CancelMarquee(MARQUEE_CHANNEL)
	self:_StopMarqueeLoop()
	self._isMarqueeActive = false
	self:_ResetMarqueeGateState()
	self.MarqueeCancelled:Fire()
end

function UnitSelectionRuntimeService:_ResetMarqueeGateState()
	self._isHoldGateArmed = false
	self._hasDragThresholdReached = false
end

return UnitSelectionRuntimeService
