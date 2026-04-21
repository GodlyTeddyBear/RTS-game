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

local PlacementCursorService = require(script.Parent.Application.PlacementCursorService)
local PlacementGhostModel = require(script.Parent.Infrastructure.PlacementGhostModel)
local PlacementHighlightPool = require(script.Parent.Infrastructure.PlacementHighlightPool)

type GridCoord = PlacementTypes.GridCoord
type PlacementAtom = PlacementTypes.PlacementAtom
type PlaceResponse = PlacementTypes.PlaceResponse
type RunState = RunTypes.RunState

local PlacementCursorController = Knit.CreateController({
	Name = "PlacementCursorController",
})

local function _GetCoordKey(coord: GridCoord?): string?
	if coord == nil then
		return nil
	end

	return ("%d_%d"):format(coord.row, coord.col)
end

local function _BuildOccupiedSet(atom: PlacementAtom?): { [string]: boolean }
	local occupiedSet = {}
	if atom == nil then
		return occupiedSet
	end

	for _, record in ipairs(atom.placements) do
		occupiedSet[("%d_%d"):format(record.coord.row, record.coord.col)] = true
	end

	return occupiedSet
end

local function _BuildPlacementSignature(atom: PlacementAtom?): string
	if atom == nil then
		return ""
	end

	local parts = table.create(#atom.placements)
	for index, record in ipairs(atom.placements) do
		parts[index] = ("%d:%d:%s:%d"):format(record.coord.row, record.coord.col, record.structureType, record.instanceId)
	end

	return table.concat(parts, "|")
end

local function _GetMouseWorldPosition(camera: Camera): Vector3?
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y, 0)
	if math.abs(ray.Direction.Y) < 1e-5 then
		return nil
	end

	local t = -ray.Origin.Y / ray.Direction.Y
	if t < 0 then
		return nil
	end

	return ray.Origin + ray.Direction * t
end

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
end

function PlacementCursorController:KnitStart()
	self._playerInputController = Knit.GetController("PlayerInputController")
	self._placementController = Knit.GetController("PlacementController")
	self._runController = Knit.GetController("RunController")

	self._placementAtom = self._placementController:GetAtom()
	self._runAtom = self._runController:GetAtom()

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
	if self._confirming then
		return
	end

	if self._state == "Active" and self._structureType == structureType then
		self:ExitPlacementMode()
		return
	end

	self:EnterPlacementMode(structureType)
end

function PlacementCursorController:EnterPlacementMode(structureType: string)
	if self._confirming then
		return
	end

	if self._state == "Active" then
		self:ExitPlacementMode()
	end

	local runState = self._runAtom()
	if runState.state ~= "Prep" then
		return
	end

	self._state = "Active"
	self._structureType = structureType
	self._confirming = false
	self._hoveredCoord = nil
	self._hoveredKey = nil
	self._isHoveredValid = false
	self._runState = runState.state
	self._placementSignature = _BuildPlacementSignature(self._placementAtom())
	self._validTileSet = {}
	self._sessionId += 1

	self._playerInputController:ToggleContext("Placement", true)

	local occupiedSet = _BuildOccupiedSet(self._placementAtom())
	local validTiles = PlacementCursorService.GetValidTiles(structureType, occupiedSet)
	self._validTiles = validTiles

	for _, coord in ipairs(validTiles) do
		self._validTileSet[_GetCoordKey(coord)] = true
	end

	self._highlightPool:ShowValidTiles(validTiles)

	local ghost = PlacementGhostModel.new(structureType)
	self._ghost = ghost
	ghost:SetValid(false)

	self._sessionJanitor:Destroy()
	self._sessionJanitor = Janitor.new()
	self._sessionJanitor:Add(RunService.RenderStepped:Connect(function()
		self:_OnRenderStepped()
	end), "Disconnect")
	self._sessionJanitor:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		self:_OnInputBegan(input, gameProcessed)
	end), "Disconnect")

	self:_UpdateHoverState()
end

function PlacementCursorController:ExitPlacementMode()
	if self._state ~= "Active" then
		return
	end

	self._state = "Idle"
	self._confirming = false
	self._structureType = nil
	self._hoveredCoord = nil
	self._hoveredKey = nil
	self._isHoveredValid = false
	self._validTiles = table.freeze({})
	self._validTileSet = {}
	self._placementSignature = ""

	self._playerInputController:ToggleContext("Placement", false)

	self._sessionJanitor:Destroy()
	self._sessionJanitor = Janitor.new()

	self._highlightPool:HideAll()

	if self._ghost ~= nil then
		self._ghost:Destroy()
		self._ghost = nil
	end

	self._placementCancelledSignal:Fire()
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
	local placementSignature = _BuildPlacementSignature(placementAtom)
	if placementSignature ~= self._placementSignature then
		self._placementSignature = placementSignature

		local occupiedSet = _BuildOccupiedSet(placementAtom)
		local validTiles = PlacementCursorService.GetValidTiles(self._structureType or "", occupiedSet)
		self._validTiles = validTiles
		self._validTileSet = {}
		for _, coord in ipairs(validTiles) do
			self._validTileSet[_GetCoordKey(coord)] = true
		end
		self._highlightPool:ShowValidTiles(validTiles)
	end

	self:_UpdateHoverState()
end

function PlacementCursorController:_UpdateHoverState()
	if self._state ~= "Active" or self._ghost == nil or self._confirming then
		return
	end

	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	local worldPos = _GetMouseWorldPosition(camera)
	if worldPos == nil then
		self._ghost:SetValid(false)
		if self._hoveredKey ~= nil then
			self._highlightPool:SetHovered(self._hoveredCoord.row, self._hoveredCoord.col, false)
			self._hoveredCoord = nil
			self._hoveredKey = nil
			self._isHoveredValid = false
		end
		return
	end

	local hoveredCoord = PlacementCursorService.WorldToCoord(worldPos)
	local hoveredKey = _GetCoordKey(hoveredCoord)
	local isHoveredValid = hoveredCoord ~= nil and self._validTileSet[hoveredKey] == true

	if hoveredKey ~= self._hoveredKey then
		if self._hoveredCoord ~= nil then
			self._highlightPool:SetHovered(self._hoveredCoord.row, self._hoveredCoord.col, false)
		end

		self._hoveredCoord = hoveredCoord
		self._hoveredKey = hoveredKey

		if hoveredCoord ~= nil then
			self._highlightPool:SetHovered(hoveredCoord.row, hoveredCoord.col, true)
			self._ghost:MoveTo(PlacementCursorService.CoordToWorld(hoveredCoord.row, hoveredCoord.col))
		end
	end

	if hoveredCoord ~= nil then
		self._ghost:MoveTo(PlacementCursorService.CoordToWorld(hoveredCoord.row, hoveredCoord.col))
	end

	self._isHoveredValid = isHoveredValid
	self._ghost:SetValid(isHoveredValid)
end

function PlacementCursorController:_OnInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or self._state ~= "Active" or self._confirming then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		self:_ConfirmPlacement()
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self:ExitPlacementMode()
	end
end

function PlacementCursorController:_ConfirmPlacement()
	if self._confirming or self._hoveredCoord == nil or self._isHoveredValid == false or self._structureType == nil then
		return
	end

	self._confirming = true
	local sessionId = self._sessionId

	local request = {
		coord_row = self._hoveredCoord.row,
		coord_col = self._hoveredCoord.col,
		structureType = self._structureType,
	}

	local ok, response = pcall(function(): PlaceResponse
		return PlacementRemoteClient.PlaceStructure.Invoke(request)
	end)

	self._confirming = false

	if not ok then
		warn("[PlacementCursor] PlaceStructure invoke failed")
		return
	end

	if sessionId ~= self._sessionId or self._state ~= "Active" then
		return
	end

	if response.success then
		self:ExitPlacementMode()
		return
	end

	if response.errorMessage then
		warn(("[PlacementCursor] %s"):format(response.errorMessage))
	else
		warn("[PlacementCursor] Placement rejected without an error message")
	end
end

return PlacementCursorController
