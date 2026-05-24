--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local UnitSelectionTypes = require(ReplicatedStorage.Contexts.UnitSelection.Types.UnitSelectionTypes)

local CommitMarqueeUnitSelectionCommand = require(script.Parent.Application.Commands.CommitMarqueeUnitSelectionCommand)
local CommitSingleUnitSelectionCommand = require(script.Parent.Application.Commands.CommitSingleUnitSelectionCommand)
local AssignUnitControlGroupCommand = require(script.Parent.Application.Commands.AssignUnitControlGroupCommand)
local ClearUnitSelectionCommand = require(script.Parent.Application.Commands.ClearUnitSelectionCommand)
local RecallUnitControlGroupCommand = require(script.Parent.Application.Commands.RecallUnitControlGroupCommand)
local RefreshUnitSelectionCommand = require(script.Parent.Application.Commands.RefreshUnitSelectionCommand)
local UpdateMarqueePreviewStateCommand = require(script.Parent.Application.Commands.UpdateMarqueePreviewStateCommand)
local BuildSelectedUnitRecordsQuery = require(script.Parent.Application.Queries.BuildSelectedUnitRecordsQuery)
local ResolveOwnedUnitSelectionQuery = require(script.Parent.Application.Queries.ResolveOwnedUnitSelectionQuery)
local ResolveOwnedUnitSelectionByUnitGuidsQuery = require(script.Parent.Application.Queries.ResolveOwnedUnitSelectionByUnitGuidsQuery)
local UnitSelectionAtom = require(script.Parent.Infrastructure.Persistence.UnitSelectionAtom)
local UnitSelectionMarqueeOverlayService = require(script.Parent.Infrastructure.Services.UnitSelectionMarqueeOverlayService)
local UnitSelectionRuntimeService = require(script.Parent.Infrastructure.Services.UnitSelectionRuntimeService)

type TUnitSelectionState = UnitSelectionTypes.TUnitSelectionState

local UnitSelectionController = Knit.CreateController({
	Name = "UnitSelectionController",
})

function UnitSelectionController:KnitInit()
	self._selectionAtom = UnitSelectionAtom()
	self._resolveOwnedUnitSelectionQuery = ResolveOwnedUnitSelectionQuery.new()
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
	self._isSelectionEnabled = true
	self._isShiftSelectionModifierActive = false
	self._isControlGroupModifierActive = false
	self._inputUnbinds = {}
end

function UnitSelectionController:KnitStart()
	self._playerInputController = Knit.GetController("PlayerInputController")
	self._placementCursorController = Knit.GetController("PlacementCursorController")
	self._deps = {
		selectionAtom = self._selectionAtom,
		buildSelectedUnitRecordsQuery = self._buildSelectedUnitRecordsQuery,
		resolveOwnedUnitSelectionQuery = self._resolveOwnedUnitSelectionQuery,
		resolveOwnedUnitSelectionByUnitGuidsQuery = self._resolveOwnedUnitSelectionByUnitGuidsQuery,
		runtimeService = self._runtimeService,
		marqueeOverlayService = self._marqueeOverlayService,
	}

	self._runtimeService.SingleSelectionRequested:Connect(function(resolvedTarget: any)
		if not self._isSelectionEnabled then
			return
		end

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

	self:_SetSelectionEnabled(not self._placementCursorController:IsActive())
	self._placementCursorController.PlacementModeChanged:Connect(function(isActive: boolean)
		self:_SetSelectionEnabled(not isActive)
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
	self._isControlGroupModifierActive = false
end

function UnitSelectionController:Destroy()
	for _, unbind in ipairs(self._inputUnbinds) do
		unbind()
	end

	if self._runtimeService ~= nil then
		self._runtimeService:Destroy()
	end

	if self._marqueeOverlayService ~= nil then
		self._marqueeOverlayService:Destroy()
	end
end

return UnitSelectionController
