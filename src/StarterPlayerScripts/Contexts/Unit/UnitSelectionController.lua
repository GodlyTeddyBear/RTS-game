--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local UnitSelectionTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitSelectionTypes)

local CommitMarqueeUnitSelectionCommand = require(script.Parent.Application.Commands.CommitMarqueeUnitSelectionCommand)
local CommitSingleUnitSelectionCommand = require(script.Parent.Application.Commands.CommitSingleUnitSelectionCommand)
local AssignUnitControlGroupCommand = require(script.Parent.Application.Commands.AssignUnitControlGroupCommand)
local ClearUnitSelectionCommand = require(script.Parent.Application.Commands.ClearUnitSelectionCommand)
local RecallUnitControlGroupCommand = require(script.Parent.Application.Commands.RecallUnitControlGroupCommand)
local RefreshUnitSelectionCommand = require(script.Parent.Application.Commands.RefreshUnitSelectionCommand)
local UpdateMarqueePreviewStateCommand = require(script.Parent.Application.Commands.UpdateMarqueePreviewStateCommand)
local BuildSelectedUnitRecordsQuery = require(script.Parent.Application.Queries.BuildSelectedUnitRecordsQuery)
local ResolveOwnedUnitSelectionFromCharacterClickQuery =
	require(script.Parent.Application.Queries.ResolveOwnedUnitSelectionFromCharacterClickQuery)
local ResolveOwnedUnitSelectionQuery = require(script.Parent.Application.Queries.ResolveOwnedUnitSelectionQuery)
local ResolveOwnedUnitSelectionByUnitGuidsQuery = require(script.Parent.Application.Queries.ResolveOwnedUnitSelectionByUnitGuidsQuery)
local UnitSelectionAtom = require(script.Parent.Infrastructure.Persistence.UnitSelectionAtom)
local UnitSelectionMarqueeOverlayService = require(script.Parent.Infrastructure.Services.UnitSelectionMarqueeOverlayService)
local UnitSelectionRuntimeService = require(script.Parent.Infrastructure.Services.UnitSelectionRuntimeService)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState
type RunState = RunTypes.RunState

local UnitSelectionController = Knit.CreateController({
	Name = "UnitSelectionController",
})

function UnitSelectionController:KnitInit()
	self._selectionAtom = UnitSelectionAtom()
	self._resolveOwnedUnitSelectionQuery = ResolveOwnedUnitSelectionQuery.new()
	self._resolveOwnedUnitSelectionFromCharacterClickQuery =
		ResolveOwnedUnitSelectionFromCharacterClickQuery.new(self._resolveOwnedUnitSelectionQuery)
	self._resolveOwnedUnitSelectionByUnitGuidsQuery =
		ResolveOwnedUnitSelectionByUnitGuidsQuery.new(self._resolveOwnedUnitSelectionQuery)
	self._buildSelectedUnitRecordsQuery = BuildSelectedUnitRecordsQuery.new()
	self._assignUnitControlGroupCommand = AssignUnitControlGroupCommand.new()
	self._clearUnitSelectionCommand = ClearUnitSelectionCommand.new()
	self._commitSingleUnitSelectionCommand = CommitSingleUnitSelectionCommand.new()
	self._commitMarqueeUnitSelectionCommand = CommitMarqueeUnitSelectionCommand.new()
	self._recallUnitControlGroupCommand = RecallUnitControlGroupCommand.new()
	self._refreshUnitSelectionCommand = RefreshUnitSelectionCommand.new()
	self._updateMarqueePreviewStateCommand = UpdateMarqueePreviewStateCommand.new()
	self._marqueeOverlayService = UnitSelectionMarqueeOverlayService.new()
	self._runtimeService = UnitSelectionRuntimeService.new()
	self._isSelectionEnabled = false
	self._isRunActive = false
	self._isSelectionModeEnabled = false
	self._isShiftSelectionModifierActive = false
	self._isAltSelectionClearModifierActive = false
	self._isControlGroupModifierActive = false
	self._lastObservedRunState = "Idle" :: RunState
	self._runStateWatcherConnection = nil :: RBXScriptConnection?
	self._inputUnbinds = {}
end

function UnitSelectionController:KnitStart()
	self._playerInputController = Knit.GetController("PlayerInputController")
	self._placementCursorController = Knit.GetController("PlacementCursorController")
	self._runController = Knit.GetController("RunController")
	self._runAtom = self._runController:GetAtom()
	self._deps = {
		selectionAtom = self._selectionAtom,
		buildSelectedUnitRecordsQuery = self._buildSelectedUnitRecordsQuery,
		resolveOwnedUnitSelectionFromCharacterClickQuery = self._resolveOwnedUnitSelectionFromCharacterClickQuery,
		resolveOwnedUnitSelectionQuery = self._resolveOwnedUnitSelectionQuery,
		resolveOwnedUnitSelectionByUnitGuidsQuery = self._resolveOwnedUnitSelectionByUnitGuidsQuery,
		runtimeService = self._runtimeService,
		marqueeOverlayService = self._marqueeOverlayService,
	}

	self._runtimeService.SingleSelectionRequested:Connect(function(gestureEvent: any)
		if not self._isSelectionEnabled then
			return
		end

		if self._isAltSelectionClearModifierActive then
			self._clearUnitSelectionCommand:Execute(self._deps)
			return
		end

		local resolvedTarget =
			self._resolveOwnedUnitSelectionFromCharacterClickQuery:Execute(gestureEvent.MouseSnapshot)
		self._commitSingleUnitSelectionCommand:Execute(
			self._deps,
			resolvedTarget,
			self._isShiftSelectionModifierActive
		)
	end)

	self._runtimeService.MarqueePreviewChanged:Connect(function(snapshot: any)
		self._updateMarqueePreviewStateCommand:Execute(self._deps, snapshot)
	end)

	self._runtimeService.MarqueeSelectionRequested:Connect(function(previewTargets: { any }?)
		if not self._isSelectionEnabled then
			return
		end

		self._commitMarqueeUnitSelectionCommand:Execute(
			self._deps,
			previewTargets,
			self._isShiftSelectionModifierActive
		)
	end)

	self._runtimeService.MarqueeCancelled:Connect(function()
		self._updateMarqueePreviewStateCommand:Execute(self._deps, nil)
	end)

	self._runtimeService.SelectionInvalidated:Connect(function(previousSnapshot: any)
		self._refreshUnitSelectionCommand:Execute(self._deps, previousSnapshot)
	end)

	table.insert(
		self._inputUnbinds,
		self._playerInputController:BindAction("ToggleSelectionMode", function(gameProcessed: boolean, _data: any)
			if gameProcessed then
				return
			end

			self:_ToggleSelectionMode()
		end)
	)
	table.insert(
		self._inputUnbinds,
		self._playerInputController:BindAction("ShiftSelectionModifier", function(gameProcessed: boolean, _data: any)
			if gameProcessed or not self._isSelectionEnabled then
				return
			end

			self._isShiftSelectionModifierActive = true
		end)
	)
	table.insert(
		self._inputUnbinds,
		self._playerInputController:BindActionDeactivated("ShiftSelectionModifier", function(_gameProcessed: boolean, _data: any)
			self._isShiftSelectionModifierActive = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		end)
	)
	table.insert(
		self._inputUnbinds,
		self._playerInputController:BindAction("AltSelectionClearModifier", function(gameProcessed: boolean, _data: any)
			if gameProcessed or not self._isSelectionEnabled then
				return
			end

			self._isAltSelectionClearModifierActive = true
		end)
	)
	table.insert(
		self._inputUnbinds,
		self._playerInputController:BindActionDeactivated("AltSelectionClearModifier", function(_gameProcessed: boolean, _data: any)
			self._isAltSelectionClearModifierActive = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
		end)
	)
	table.insert(
		self._inputUnbinds,
		self._playerInputController:BindAction("ControlGroupModifier", function(gameProcessed: boolean, _data: any)
			if gameProcessed or not self._isSelectionEnabled then
				return
			end

			self._isControlGroupModifierActive = true
		end)
	)
	table.insert(
		self._inputUnbinds,
		self._playerInputController:BindActionDeactivated("ControlGroupModifier", function(_gameProcessed: boolean, _data: any)
			self._isControlGroupModifierActive = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		end)
	)

	for slot = 0, 9 do
		table.insert(
			self._inputUnbinds,
			self._playerInputController:BindAction(`RecallControlGroup{slot}`, function(gameProcessed: boolean, _data: any)
				if gameProcessed or not self._isSelectionEnabled then
					return
				end

				if self._isControlGroupModifierActive then
					self._assignUnitControlGroupCommand:Execute(self._deps, slot)
					return
				end

				self._recallUnitControlGroupCommand:Execute(self._deps, slot)
			end)
		)
	end

	self:_ApplyRunState(self:_GetCurrentRunState())
	self._placementCursorController.PlacementModeChanged:Connect(function(_isActive: boolean)
		self:_ApplyRunState(self:_GetCurrentRunState())
	end)
	self._runStateWatcherConnection = RunService.Heartbeat:Connect(function()
		self:_ObserveRunStateChanges()
	end)

	self._runtimeService:Start()
end

function UnitSelectionController:GetAtom(): () -> TUnitSelectionState
	return self._selectionAtom
end

function UnitSelectionController:GetSelectedUnitGuids(): { string }
	return self._selectionAtom().SelectedUnitGuids
end

function UnitSelectionController:ClearSelection()
	self._clearUnitSelectionCommand:Execute(self._deps)
end

function UnitSelectionController:_SetSelectionEnabled(isEnabled: boolean)
	self._isSelectionEnabled = isEnabled
	self._runtimeService:SetSelectionEnabled(isEnabled)
	self._playerInputController:ToggleContext("Selection", isEnabled)

	if isEnabled then
		return
	end

	self._isShiftSelectionModifierActive = false
	self._isAltSelectionClearModifierActive = false
	self._isControlGroupModifierActive = false
end

function UnitSelectionController:_RefreshSelectionEnabledState()
	self:_SetSelectionEnabled(self:_ShouldEnableSelection())
end

function UnitSelectionController:_ShouldEnableSelection(): boolean
	return self._isRunActive and self._isSelectionModeEnabled and not self._placementCursorController:IsActive()
end

function UnitSelectionController:_ToggleSelectionMode()
	self._isSelectionModeEnabled = not self._isSelectionModeEnabled

	if not self._isSelectionModeEnabled then
		self._clearUnitSelectionCommand:Execute(self._deps)
	end

	self:_RefreshSelectionEnabledState()
end

function UnitSelectionController:_ObserveRunStateChanges()
	local currentRunState = self:_GetCurrentRunState()
	if currentRunState == self._lastObservedRunState then
		return
	end

	self:_ApplyRunState(currentRunState)
end

function UnitSelectionController:_GetCurrentRunState(): RunState
	local runState = self._runAtom()
	return runState.State
end

function UnitSelectionController:_ApplyRunState(runState: RunState)
	local wasRunActive = self._isRunActive

	self._lastObservedRunState = runState
	self._isRunActive = self:_IsRunActive(runState)

	if wasRunActive and not self._isRunActive then
		self._clearUnitSelectionCommand:Execute(self._deps)
	end

	self:_RefreshSelectionEnabledState()
end

function UnitSelectionController:_IsRunActive(runState: RunState): boolean
	return runState == "Prep"
		or runState == "Wave"
		or runState == "Resolution"
		or runState == "Climax"
		or runState == "Endless"
end

function UnitSelectionController:Destroy()
	for _, unbind in ipairs(self._inputUnbinds) do
		unbind()
	end

	if self._runStateWatcherConnection ~= nil then
		self._runStateWatcherConnection:Disconnect()
		self._runStateWatcherConnection = nil
	end

	if self._runtimeService ~= nil then
		self._runtimeService:Destroy()
	end

	if self._marqueeOverlayService ~= nil then
		self._marqueeOverlayService:Destroy()
	end
end

return UnitSelectionController
