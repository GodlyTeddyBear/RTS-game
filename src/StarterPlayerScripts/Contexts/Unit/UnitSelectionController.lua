--!strict

--[=[
    @class UnitSelectionController
    Owns the client-side unit selection flow, input binding, and runtime selection state transitions.

    Flow: Resolve dependencies -> bind selection inputs -> react to runtime events -> keep selection state and overlays in sync.
    Owns orchestration only; does not own selection math, target resolution, or overlay rendering details.
    @client
]=]

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
local IssueUnitMoveOrderCommand = require(script.Parent.Application.Commands.IssueUnitMoveOrderCommand)
local RecallUnitControlGroupCommand = require(script.Parent.Application.Commands.RecallUnitControlGroupCommand)
local RefreshUnitSelectionCommand = require(script.Parent.Application.Commands.RefreshUnitSelectionCommand)
local UpdateMarqueePreviewStateCommand = require(script.Parent.Application.Commands.UpdateMarqueePreviewStateCommand)
local BuildMoveOrderUnitGuidsQuery = require(script.Parent.Application.Queries.BuildMoveOrderUnitGuidsQuery)
local BuildSelectedUnitRecordsQuery = require(script.Parent.Application.Queries.BuildSelectedUnitRecordsQuery)
local ResolveMoveOrderDestinationQuery = require(script.Parent.Application.Queries.ResolveMoveOrderDestinationQuery)
local ResolveOwnedUnitSelectionFromCharacterClickQuery =
	require(script.Parent.Application.Queries.ResolveOwnedUnitSelectionFromCharacterClickQuery)
local ResolveOwnedUnitSelectionQuery = require(script.Parent.Application.Queries.ResolveOwnedUnitSelectionQuery)
local ResolveOwnedUnitSelectionByUnitGuidsQuery = require(script.Parent.Application.Queries.ResolveOwnedUnitSelectionByUnitGuidsQuery)
local UnitSelectionAtom = require(script.Parent.Infrastructure.Persistence.UnitSelectionAtom)
local UnitMoveOrderPreviewService = require(script.Parent.Infrastructure.Services.UnitMoveOrderPreviewService)
local UnitSelectionMarqueeOverlayService = require(script.Parent.Infrastructure.Services.UnitSelectionMarqueeOverlayService)
local UnitSelectionRuntimeService = require(script.Parent.Infrastructure.Services.UnitSelectionRuntimeService)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState
type RunState = RunTypes.RunState

local UnitSelectionController = Knit.CreateController({
	Name = "UnitSelectionController",
})

--[=[
    Initializes the controller's atom, commands, queries, services, and runtime state flags.

    @within UnitSelectionController
]=]
function UnitSelectionController:KnitInit()
	self._selectionAtom = UnitSelectionAtom()
	self._resolveOwnedUnitSelectionQuery = ResolveOwnedUnitSelectionQuery.new()
	self._resolveOwnedUnitSelectionFromCharacterClickQuery =
		ResolveOwnedUnitSelectionFromCharacterClickQuery.new(self._resolveOwnedUnitSelectionQuery)
	self._resolveOwnedUnitSelectionByUnitGuidsQuery =
		ResolveOwnedUnitSelectionByUnitGuidsQuery.new(self._resolveOwnedUnitSelectionQuery)
	self._buildMoveOrderUnitGuidsQuery = BuildMoveOrderUnitGuidsQuery.new()
	self._resolveMoveOrderDestinationQuery = ResolveMoveOrderDestinationQuery.new()
	self._buildSelectedUnitRecordsQuery = BuildSelectedUnitRecordsQuery.new()
	self._assignUnitControlGroupCommand = AssignUnitControlGroupCommand.new()
	self._clearUnitSelectionCommand = ClearUnitSelectionCommand.new()
	self._commitSingleUnitSelectionCommand = CommitSingleUnitSelectionCommand.new()
	self._commitMarqueeUnitSelectionCommand = CommitMarqueeUnitSelectionCommand.new()
	self._issueUnitMoveOrderCommand = IssueUnitMoveOrderCommand.new()
	self._recallUnitControlGroupCommand = RecallUnitControlGroupCommand.new()
	self._refreshUnitSelectionCommand = RefreshUnitSelectionCommand.new()
	self._updateMarqueePreviewStateCommand = UpdateMarqueePreviewStateCommand.new()
	self._marqueeOverlayService = UnitSelectionMarqueeOverlayService.new()
	self._moveOrderPreviewService = UnitMoveOrderPreviewService.new()
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

--[=[
    Wires the controller to the player input, run state, and runtime selection signals.

    @within UnitSelectionController
]=]
function UnitSelectionController:KnitStart()
	self._playerInputController = Knit.GetController("PlayerInputController")
	self._placementCursorController = Knit.GetController("PlacementCursorController")
	self._runController = Knit.GetController("RunController")
	self._unitContext = Knit.GetService("UnitContext")
	self._runAtom = self._runController:GetAtom()
	self._deps = {
		selectionAtom = self._selectionAtom,
		buildMoveOrderUnitGuidsQuery = self._buildMoveOrderUnitGuidsQuery,
		buildSelectedUnitRecordsQuery = self._buildSelectedUnitRecordsQuery,
		resolveMoveOrderDestinationQuery = self._resolveMoveOrderDestinationQuery,
		resolveOwnedUnitSelectionFromCharacterClickQuery = self._resolveOwnedUnitSelectionFromCharacterClickQuery,
		resolveOwnedUnitSelectionQuery = self._resolveOwnedUnitSelectionQuery,
		resolveOwnedUnitSelectionByUnitGuidsQuery = self._resolveOwnedUnitSelectionByUnitGuidsQuery,
		unitContext = self._unitContext,
		runtimeService = self._runtimeService,
		marqueeOverlayService = self._marqueeOverlayService,
	}

	-- Route single clicks through the selection, clear, and move-order command paths.
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
		if resolvedTarget == nil then
			local issuedMoveOrderPreview = self._issueUnitMoveOrderCommand:Execute(self._deps, gestureEvent.MouseSnapshot)
			if issuedMoveOrderPreview ~= nil then
				self._moveOrderPreviewService:ShowOrder(issuedMoveOrderPreview)
			end
			return
		end

		self._commitSingleUnitSelectionCommand:Execute(
			self._deps,
			resolvedTarget,
			self._isShiftSelectionModifierActive
		)
	end)

	-- Keep marquee preview state and overlay visibility in sync with the runtime gesture stream.
	self._runtimeService.MarqueePreviewChanged:Connect(function(snapshot: any)
		self._updateMarqueePreviewStateCommand:Execute(self._deps, snapshot)
	end)

	-- Commit marquee selections only when selection mode is active.
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

	-- Clear the overlay when the runtime cancels marquee mode.
	self._runtimeService.MarqueeCancelled:Connect(function()
		self._updateMarqueePreviewStateCommand:Execute(self._deps, nil)
	end)

	-- Rebuild the selection from the runtime snapshot whenever invalidation drops stale entries.
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

	-- Bind the recall hotkeys after the modifier handlers so control-group assignment can reuse the same keys.
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
	self._placementCursorController.PlacementModeChanged:Connect(function(isActive: boolean)
		if isActive then
			self._moveOrderPreviewService:Clear()
		end

		self:_ApplyRunState(self:_GetCurrentRunState())
	end)
	self._runStateWatcherConnection = RunService.Heartbeat:Connect(function()
		self:_ObserveRunStateChanges()
	end)

	self._runtimeService:Start()
end

-- Returns the atom that backs the controller's selection snapshot.
function UnitSelectionController:GetAtom(): () -> TUnitSelectionState
	return self._selectionAtom
end

-- Returns the currently selected unit GUIDs for other client contexts that need read-only access.
function UnitSelectionController:GetSelectedUnitGuids(): { string }
	return self._selectionAtom().SelectedUnitGuids
end

-- Clears the current selection without changing the controller's mode flags.
function UnitSelectionController:ClearSelection()
	self._clearUnitSelectionCommand:Execute(self._deps)
end

-- Enables or disables selection input while preserving the rest of the runtime state.
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

-- Recomputes whether selection input should be active and mirrors that state into the runtime service.
function UnitSelectionController:_RefreshSelectionEnabledState()
	self:_SetSelectionEnabled(self:_ShouldEnableSelection())
end

-- Selection is only active while the run is live, selection mode is on, and placement mode is inactive.
function UnitSelectionController:_ShouldEnableSelection(): boolean
	return self._isRunActive and self._isSelectionModeEnabled and not self._placementCursorController:IsActive()
end

-- Toggles selection mode and clears the current selection when leaving the mode.
function UnitSelectionController:_ToggleSelectionMode()
	self._isSelectionModeEnabled = not self._isSelectionModeEnabled

	if not self._isSelectionModeEnabled then
		self._clearUnitSelectionCommand:Execute(self._deps)
	end

	self:_RefreshSelectionEnabledState()
end

-- Polls the run atom and only reapplies state when the observed run phase changes.
function UnitSelectionController:_ObserveRunStateChanges()
	local currentRunState = self:_GetCurrentRunState()
	if currentRunState == self._lastObservedRunState then
		return
	end

	self:_ApplyRunState(currentRunState)
end

-- Reads the current run phase from the run atom.
function UnitSelectionController:_GetCurrentRunState(): RunState
	local runState = self._runAtom()
	return runState.State
end

-- Mirrors the run phase into local flags and clears selection when a live run ends.
function UnitSelectionController:_ApplyRunState(runState: RunState)
	local wasRunActive = self._isRunActive

	self._lastObservedRunState = runState
	self._isRunActive = self:_IsRunActive(runState)

	if wasRunActive and not self._isRunActive then
		self._clearUnitSelectionCommand:Execute(self._deps)
		self._moveOrderPreviewService:Clear()
	end

	self:_RefreshSelectionEnabledState()
end

-- Treats the active gameplay phases as the only phases where unit selection should be live.
function UnitSelectionController:_IsRunActive(runState: RunState): boolean
	return runState == "Prep"
		or runState == "Wave"
		or runState == "Resolution"
		or runState == "Climax"
		or runState == "Endless"
end

--[=[
    Disconnects controller bindings and destroys the runtime services it owns.

    @within UnitSelectionController
]=]
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

	if self._moveOrderPreviewService ~= nil then
		self._moveOrderPreviewService:Destroy()
	end
end

return UnitSelectionController
