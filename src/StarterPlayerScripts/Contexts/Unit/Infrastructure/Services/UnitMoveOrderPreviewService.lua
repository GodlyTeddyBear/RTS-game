--!strict

--[=[
    @class UnitMoveOrderPreviewService
    Owns the client-side move-order preview visuals that show unit paths toward the issued destination.

    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local VectorViz = require(ReplicatedStorage.Utilities.VectorViz)

local DESTINATION_FOLDER_NAME = "UnitMovePreview"
local DESTINATION_MARKER_NAME = "MoveDestinationMarker"
local DESTINATION_RING_HEIGHT = 0.2
local DESTINATION_RING_ROTATION = CFrame.Angles(0, 0, math.rad(90))
local DESTINATION_RING_RADIUS = WorldConfig.TILE_SIZE * 0.75
local DESTINATION_RING_COLOR = Color3.fromRGB(99, 190, 255)
local DESTINATION_RING_TRANSPARENCY = 0.35
local DESTINATION_RING_Y_OFFSET = 0.05
local BEAM_COLOR = DESTINATION_RING_COLOR
local BEAM_WIDTH = 0.18
local ARRIVAL_RADIUS = math.max(WorldConfig.TILE_SIZE * 0.5, 3)
local BEAM_ORIGIN_GROUND_OFFSET = 0.2

export type TMoveOrderPreviewPayload = {
	Destination: Vector3,
	UnitGuids: { string },
	RootsByGuid: { [string]: Instance },
}

type TTrackedUnit = {
	Root: Instance,
	BeamId: string,
}

local UnitMoveOrderPreviewService = {}
UnitMoveOrderPreviewService.__index = UnitMoveOrderPreviewService

-- Ensures the preview folder exists so visual objects have a stable parent.
local function _EnsurePreviewFolder(): Folder
	local existingFolder = Workspace:FindFirstChild(DESTINATION_FOLDER_NAME)
	if existingFolder ~= nil and existingFolder:IsA("Folder") then
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = DESTINATION_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

-- Resolves the current root position for live arrival checks and beam updates.
local function _ResolveRootPosition(root: Instance): Vector3?
	if root.Parent == nil then
		return nil
	end

	if root:IsA("Model") then
		return root:GetPivot().Position
	end

	if root:IsA("BasePart") then
		return root.Position
	end

	return nil
end

-- Resolves the beam origin near the ground so the preview lines read cleanly from the unit's base.
local function _ResolveBeamOrigin(root: Instance): Vector3?
	if root.Parent == nil then
		return nil
	end

	if root:IsA("Model") then
		local boundsCFrame, boundsSize = root:GetBoundingBox()
		return boundsCFrame.Position - Vector3.new(0, boundsSize.Y * 0.5 - BEAM_ORIGIN_GROUND_OFFSET, 0)
	end

	if root:IsA("BasePart") then
		return root.Position - Vector3.new(0, root.Size.Y * 0.5 - BEAM_ORIGIN_GROUND_OFFSET, 0)
	end

	return _ResolveRootPosition(root)
end

-- Builds the destination ring that anchors the preview destination in the world.
local function _BuildDestinationMarker(destination: Vector3, parent: Instance): Part
	local radiusPart = Instance.new("Part")
	radiusPart.Name = DESTINATION_MARKER_NAME
	radiusPart.Anchored = true
	radiusPart.CanCollide = false
	radiusPart.CanQuery = false
	radiusPart.CanTouch = false
	radiusPart.CastShadow = false
	radiusPart.Material = Enum.Material.ForceField
	radiusPart.Shape = Enum.PartType.Cylinder
	radiusPart.Color = DESTINATION_RING_COLOR
	radiusPart.Transparency = DESTINATION_RING_TRANSPARENCY
	radiusPart.Size = Vector3.new(DESTINATION_RING_HEIGHT, DESTINATION_RING_RADIUS * 2, DESTINATION_RING_RADIUS * 2)
	radiusPart.CFrame = CFrame.new(destination + Vector3.new(0, DESTINATION_RING_HEIGHT * 0.5 + DESTINATION_RING_Y_OFFSET, 0))
		* DESTINATION_RING_ROTATION
	radiusPart.Parent = parent
	return radiusPart
end

-- Creates the preview service with empty visual state and a reusable preview folder.
function UnitMoveOrderPreviewService.new()
	local self = setmetatable({}, UnitMoveOrderPreviewService)
	self._previewFolder = _EnsurePreviewFolder()
	self._destination = nil :: Vector3?
	self._destinationMarker = nil :: Part?
	self._trackedUnitsByGuid = {} :: { [string]: TTrackedUnit }
	self._renderConnection = nil :: RBXScriptConnection?
	return self
end

-- Shows a move-order preview for the requested payload and starts the render loop when at least one beam is valid.
function UnitMoveOrderPreviewService:ShowOrder(payload: TMoveOrderPreviewPayload)
	self:Clear()

	if typeof(payload) ~= "table" or typeof(payload.Destination) ~= "Vector3" then
		return
	end

	local trackedUnitGuids = payload.UnitGuids
	local rootsByGuid = payload.RootsByGuid
	if type(trackedUnitGuids) ~= "table" or type(rootsByGuid) ~= "table" then
		return
	end

	self._destination = payload.Destination
	self._destinationMarker = _BuildDestinationMarker(payload.Destination, self._previewFolder)

	for _, unitGuid in ipairs(trackedUnitGuids) do
		local root = rootsByGuid[unitGuid]
		if type(unitGuid) ~= "string" or root == nil or root.Parent == nil then
			continue
		end

		local beamOrigin = _ResolveBeamOrigin(root)
		if beamOrigin == nil then
			continue
		end

		local beamId = self:_BuildBeamId(unitGuid)
		self._trackedUnitsByGuid[unitGuid] = {
			Root = root,
			BeamId = beamId,
		}
		self:_UpsertBeam(beamId, beamOrigin, payload.Destination)
	end

	if next(self._trackedUnitsByGuid) == nil then
		self:Clear()
		return
	end

	self:_StartRenderLoop()
end

-- Clears all preview visuals and stops the render loop.
function UnitMoveOrderPreviewService:Clear()
	self:_StopRenderLoop()

	for unitGuid, trackedUnit in pairs(self._trackedUnitsByGuid) do
		VectorViz:DestroyVisualiser(trackedUnit.BeamId)
		self._trackedUnitsByGuid[unitGuid] = nil
	end

	if self._destinationMarker ~= nil then
		self._destinationMarker:Destroy()
		self._destinationMarker = nil
	end

	self._destination = nil
end

-- Clears the preview so destroy remains a single cleanup path.
function UnitMoveOrderPreviewService:Destroy()
	self:Clear()
end

-- Builds a stable beam identifier for each tracked unit GUID.
function UnitMoveOrderPreviewService:_BuildBeamId(unitGuid: string): string
	return `UnitMovePreview_{unitGuid}`
end

-- Starts the render loop only when the preview actually has something to animate.
function UnitMoveOrderPreviewService:_StartRenderLoop()
	if self._renderConnection ~= nil then
		return
	end

	self._renderConnection = RunService.RenderStepped:Connect(function()
		self:_OnRenderStepped()
	end)
end

-- Stops the render loop when the preview is cleared or all tracked units have arrived.
function UnitMoveOrderPreviewService:_StopRenderLoop()
	if self._renderConnection == nil then
		return
	end

	self._renderConnection:Disconnect()
	self._renderConnection = nil
end

-- Creates or updates the beam visualizer and reparents its parts under the preview folder.
function UnitMoveOrderPreviewService:_UpsertBeam(beamId: string, origin: Vector3, destination: Vector3)
	local direction = destination - origin
	VectorViz:CreateVisualiser(beamId, origin, direction, {
		Colour = BEAM_COLOR,
		Width = BEAM_WIDTH,
	})

	local visualObject = VectorViz.VisualObjects[beamId]
	if visualObject == nil then
		return
	end

	visualObject.Visualisers.Beam.Parent = self._previewFolder
	visualObject.Visualisers.Attachment0.Parent = self._previewFolder
	visualObject.Visualisers.Attachment1.Parent = self._previewFolder
end

-- Removes a tracked unit and its beam when the unit disappears or reaches the destination.
function UnitMoveOrderPreviewService:_RemoveTrackedUnit(unitGuid: string)
	local trackedUnit = self._trackedUnitsByGuid[unitGuid]
	if trackedUnit == nil then
		return
	end

	VectorViz:DestroyVisualiser(trackedUnit.BeamId)
	self._trackedUnitsByGuid[unitGuid] = nil
end

-- Treats a unit as arrived once it is close enough to the destination to stop drawing the preview beam.
function UnitMoveOrderPreviewService:_HasUnitArrived(root: Instance, destination: Vector3): boolean
	local rootPosition = _ResolveRootPosition(root)
	if rootPosition == nil then
		return true
	end

	return (rootPosition - destination).Magnitude <= ARRIVAL_RADIUS
end

-- Repositions beams while the preview is alive and clears everything once the last tracked unit is done.
function UnitMoveOrderPreviewService:_OnRenderStepped()
	local destination = self._destination
	if destination == nil then
		self:Clear()
		return
	end

	local unitGuidsToClear = {}
	local trackedUnitCount = 0

	for unitGuid, trackedUnit in pairs(self._trackedUnitsByGuid) do
		if trackedUnit.Root == nil or trackedUnit.Root.Parent == nil then
			unitGuidsToClear[#unitGuidsToClear + 1] = unitGuid
			continue
		end

		if self:_HasUnitArrived(trackedUnit.Root, destination) then
			unitGuidsToClear[#unitGuidsToClear + 1] = unitGuid
			continue
		end

		local beamOrigin = _ResolveBeamOrigin(trackedUnit.Root)
		if beamOrigin == nil then
			unitGuidsToClear[#unitGuidsToClear + 1] = unitGuid
			continue
		end

		VectorViz:UpdateBeam(trackedUnit.BeamId, beamOrigin, destination - beamOrigin)
		trackedUnitCount += 1
	end

	for _, unitGuid in ipairs(unitGuidsToClear) do
		self:_RemoveTrackedUnit(unitGuid)
	end

	if trackedUnitCount > 0 then
		return
	end

	self:Clear()
end

return UnitMoveOrderPreviewService
