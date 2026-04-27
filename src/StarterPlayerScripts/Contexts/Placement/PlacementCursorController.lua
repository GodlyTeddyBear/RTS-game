--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Knit = require(ReplicatedStorage.Packages.Knit)

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local PlacementRemoteClient = require(ReplicatedStorage.Network.Generated.PlacementRemoteClient)

local PlacementCursorGridService = require(script.Parent.Infrastructure.Services.PlacementCursorGridService)
local PlacementGhostModel = require(script.Parent.Infrastructure.Services.PlacementGhostModel)
local PlacementHighlightPool = require(script.Parent.Infrastructure.Services.PlacementHighlightPool)

local BuildOccupiedSetQuery = require(script.Parent.Application.Queries.BuildOccupiedSetQuery)
local BuildPlacementSignatureQuery = require(script.Parent.Application.Queries.BuildPlacementSignatureQuery)
local GetMouseWorldPositionQuery = require(script.Parent.Application.Queries.GetMouseWorldPositionQuery)
local GetValidTilesQuery = require(script.Parent.Application.Queries.GetValidTilesQuery)

local ExitPlacementModeCommand = require(script.Parent.Application.Commands.ExitPlacementModeCommand)
local EnterPlacementModeCommand = require(script.Parent.Application.Commands.EnterPlacementModeCommand)
local TogglePlacementModeCommand = require(script.Parent.Application.Commands.TogglePlacementModeCommand)
local RefreshValidTilesCommand = require(script.Parent.Application.Commands.RefreshValidTilesCommand)
local UpdateHoverStateCommand = require(script.Parent.Application.Commands.UpdateHoverStateCommand)
local ConfirmPlacementCommand = require(script.Parent.Application.Commands.ConfirmPlacementCommand)

type GridCoord = PlacementTypes.GridCoord
type PlacementAtom = PlacementTypes.PlacementAtom
type RunState = RunTypes.RunState

local PlacementCursorController = Knit.CreateController({
	Name = "PlacementCursorController",
})

function PlacementCursorController:KnitInit()
	self._controllerJanitor = Janitor.new()
	self._sessionJanitor = Janitor.new()
	self._state = "Idle"
	self._confirming = false
	self._sessionId = 0
	self._structureType = nil :: string?
	self._hoveredCoord = nil :: GridCoord?
	self._hoveredKey = nil :: string?
	self._isHoveredValid = false
	self._runState = "Idle" :: RunState
	self._placementSignature = ""
	self._validTiles = table.freeze({})
	self._validTileSet = {}

	local placementFolder = Workspace:FindFirstChild("PlacementCursor")
	if placementFolder == nil then
		placementFolder = Instance.new("Folder")
		placementFolder.Name = "PlacementCursor"
		placementFolder.Parent = Workspace
	end

	self._placementFolder = placementFolder :: Folder
	self._highlightPool = PlacementHighlightPool.new(self._placementFolder)
	self._ghost = nil

	self._placementCancelledSignal = Instance.new("BindableEvent")
	self.PlacementCancelled = self._placementCancelledSignal.Event
	self._controllerJanitor:Add(self._placementCancelledSignal, "Destroy")

	self._buildOccupiedSetQuery = BuildOccupiedSetQuery.new()
	self._buildPlacementSignatureQuery = BuildPlacementSignatureQuery.new()
	self._getMouseWorldPositionQuery = GetMouseWorldPositionQuery.new()
	self._getValidTilesQuery = GetValidTilesQuery.new(PlacementCursorGridService)

	self._exitPlacementModeCommand = ExitPlacementModeCommand.new()
	self._enterPlacementModeCommand = EnterPlacementModeCommand.new(
		self._exitPlacementModeCommand,
		self._buildOccupiedSetQuery,
		self._buildPlacementSignatureQuery,
		self._getValidTilesQuery
	)
	self._togglePlacementModeCommand = TogglePlacementModeCommand.new(
		self._enterPlacementModeCommand,
		self._exitPlacementModeCommand
	)
	self._refreshValidTilesCommand = RefreshValidTilesCommand.new(
		self._buildOccupiedSetQuery,
		self._buildPlacementSignatureQuery,
		self._getValidTilesQuery
	)
	self._updateHoverStateCommand = UpdateHoverStateCommand.new(
		self._getMouseWorldPositionQuery,
		PlacementCursorGridService
	)
	self._confirmPlacementCommand = ConfirmPlacementCommand.new(self._exitPlacementModeCommand)
end

function PlacementCursorController:KnitStart()
	self._playerInputController = Knit.GetController("PlayerInputController")
	self._placementController = Knit.GetController("PlacementController")
	self._runController = Knit.GetController("RunController")

	self._placementAtom = self._placementController:GetAtom()
	self._runAtom = self._runController:GetAtom()

	self._commandDeps = {
		placementAtom = self._placementAtom,
		runAtom = self._runAtom,
		playerInputController = self._playerInputController,
		placementRemoteClient = PlacementRemoteClient,
		ghostModelModule = PlacementGhostModel,
		gridService = PlacementCursorGridService,
		runService = RunService,
		userInputService = UserInputService,
		workspace = Workspace,
		janitorFactory = Janitor,
		onRenderStepped = function()
			self:_OnRenderStepped()
		end,
		onInputBegan = function(input: InputObject, gameProcessed: boolean)
			self:_OnInputBegan(input, gameProcessed)
		end,
		updateHoverState = function()
			self:_UpdateHoverState()
		end,
	}

	self._cancelPlacementUnbind = self._playerInputController:BindAction("CancelPlacement", function(gameProcessed: boolean, _data: any)
		if gameProcessed or self._confirming then
			return
		end

		self:ExitPlacementMode()
	end)

	self._controllerJanitor:Add(function()
		if self._cancelPlacementUnbind then
			self._cancelPlacementUnbind()
			self._cancelPlacementUnbind = nil
		end
	end)
end

function PlacementCursorController:TogglePlacementMode(structureType: string)
	self._togglePlacementModeCommand:Execute(self, self._commandDeps, structureType)
end

function PlacementCursorController:EnterPlacementMode(structureType: string)
	self._enterPlacementModeCommand:Execute(self, self._commandDeps, structureType)
end

function PlacementCursorController:ExitPlacementMode()
	self._exitPlacementModeCommand:Execute(self, self._commandDeps)
end

function PlacementCursorController:Destroy()
	self:ExitPlacementMode()
	self._sessionJanitor:Destroy()
	self._controllerJanitor:Destroy()
	if self._highlightPool ~= nil then
		self._highlightPool:Destroy()
	end
end

function PlacementCursorController:_OnRenderStepped()
	if self._state ~= "Active" then
		return
	end

	local runState = self._runAtom()
	if runState.state ~= self._runState then
		self._runState = runState.state
		if runState.state ~= "Prep" then
			self:ExitPlacementMode()
			return
		end
	end

	local placementAtom = self._placementAtom()
	local placementSignature = self._buildPlacementSignatureQuery:Execute(placementAtom)
	if placementSignature ~= self._placementSignature then
		self._refreshValidTilesCommand:Execute(self, placementAtom)
	end

	self:_UpdateHoverState()
end

function PlacementCursorController:_UpdateHoverState()
	self._updateHoverStateCommand:Execute(self, self._commandDeps)
end

function PlacementCursorController:_OnInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or self._state ~= "Active" or self._confirming then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		self:_ConfirmPlacement()
		return
	end
end

function PlacementCursorController:_ConfirmPlacement()
	self._confirmPlacementCommand:Execute(self, self._commandDeps)
end

return PlacementCursorController
