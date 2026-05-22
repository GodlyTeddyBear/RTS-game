--!strict

--[=[
    @class PlacementGhostModel
    Wraps the client-side placement ghost model and its presentation-only styling.

    The placement cursor controller creates this wrapper while placement mode is active,
    moves it to hovered coordinates, and tints it to reflect validity. It does not own
    placement rules or server-authoritative state.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)

local PlacementGhostModel = {}
PlacementGhostModel.__index = PlacementGhostModel

local GHOST_CONFIG = PlacementConfig.GHOST
local VALID_COLOR = GHOST_CONFIG.ValidColor
local INVALID_COLOR = GHOST_CONFIG.InvalidColor

-- Applies the translucent, non-interactive ghost styling to every visible part.
local function _ApplyGhostStyle(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Transparency = GHOST_CONFIG.Transparency
		end
	end
end

-- Resolves the structure registry from ReplicatedStorage and returns its source folder.
local function _CreateStructureRegistry()
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder == nil then
		return nil, nil
	end

	local structuresFolder = assetsFolder:FindFirstChild("Structures")
	if structuresFolder == nil or not structuresFolder:IsA("Folder") then
		return nil, nil
	end

	return AssetFetcher.CreateStructureRegistry(structuresFolder), structuresFolder
end

local structureRegistry, structuresFolder = _CreateStructureRegistry()

-- Builds a fallback extractor model when the authored asset is missing in development.
local function _CreateExtractorFallbackModel(): Model
	local model = Instance.new("Model")
	model.Name = MiningConfig.EXTRACTOR_STRUCTURE_TYPE

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.Size = Vector3.new(5, 1, 5)
	base.Color = Color3.fromRGB(78, 83, 92)
	base.Material = Enum.Material.Metal
	base.Parent = model

	local core = Instance.new("Part")
	core.Name = "ExtractorCore"
	core.Anchored = true
	core.CanCollide = false
	core.Size = Vector3.new(2, 4, 2)
	core.Position = Vector3.new(0, 2.5, 0)
	core.Color = Color3.fromRGB(202, 170, 76)
	core.Material = Enum.Material.DiamondPlate
	core.Parent = model

	model.PrimaryPart = base
	return model
end

-- Resolves the template model for the requested structure type and preserves a fallback path for extractor previews.
local function _FindTemplateModel(structureType: string): Model?
	if structureType == MiningConfig.EXTRACTOR_STRUCTURE_TYPE then
		local typeNode = structuresFolder and structuresFolder:FindFirstChild(structureType) or nil
		if typeNode == nil then
			return _CreateExtractorFallbackModel()
		end
	end

	if structureRegistry ~= nil then
		local model = structureRegistry:GetStructureModel(structureType)
		if model ~= nil then
			return model
		end
	end

	if structureType == MiningConfig.EXTRACTOR_STRUCTURE_TYPE then
		return _CreateExtractorFallbackModel()
	end

	return nil
end

-- [Public API]

--[=[
    Creates a new ghost model for the requested structure type.
    @within PlacementGhostModel
    @param structureType string -- The structure type to preview.
    @return PlacementGhostModel -- The wrapper around the spawned ghost model.
    @error string -- Thrown when no structure model exists for the requested type.
]=]
function PlacementGhostModel.new(structureType: string)
	-- Resolve the template before any styling so we can fail fast on missing assets.
	local model = _FindTemplateModel(structureType)
	if model == nil then
		error("PlacementGhostModel: missing structure model for type '" .. structureType .. "'")
	end

	-- Make the template non-interactive and translucent for placement preview.
	_ApplyGhostStyle(model)

	if model.PrimaryPart == nil then
		-- Preserve movement support for models that do not declare a PrimaryPart.
		local primaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		if primaryPart ~= nil then
			model.PrimaryPart = primaryPart
		end
	end

	-- Parent the preview into Workspace so the cursor controller can move it immediately.
	model.Parent = Workspace

	local self = setmetatable({}, PlacementGhostModel)
	self._model = model
	self._baseRotation = model:GetPivot() - model:GetPivot().Position
	return self
end

-- Moves the ghost so its bottom face stays anchored to the hovered world position.
function PlacementGhostModel:MoveTo(worldPos: Vector3)
	ModelPlus.MoveBottomAligned(self._model, worldPos)
end

function PlacementGhostModel:SetRotationQuarterTurns(rotationQuarterTurns: number)
	local normalizedTurns = rotationQuarterTurns % 4
	if normalizedTurns < 0 then
		normalizedTurns += 4
	end

	local currentPivot = self._model:GetPivot()
	local targetRotation = CFrame.Angles(0, math.rad(normalizedTurns * 90), 0) * self._baseRotation
	self._model:PivotTo(CFrame.new(currentPivot.Position) * targetRotation)
end

-- Tints the ghost to communicate whether the hovered tile is currently valid.
function PlacementGhostModel:SetValid(isValid: boolean)
	local tint = if isValid then VALID_COLOR else INVALID_COLOR
	for _, descendant in ipairs(self._model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = tint
		end
	end
end

-- Destroys the underlying model when the placement session ends.
function PlacementGhostModel:Destroy()
	if self._model ~= nil then
		self._model:Destroy()
		self._model = nil
	end
end

return PlacementGhostModel
