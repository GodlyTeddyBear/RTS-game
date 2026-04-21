--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)

local PlacementGhostModel = {}
PlacementGhostModel.__index = PlacementGhostModel

local VALID_COLOR = Color3.fromRGB(0, 200, 100)
local INVALID_COLOR = Color3.fromRGB(200, 50, 50)

local function _ApplyGhostStyle(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Transparency = 0.5
		end
	end
end

local function _CreateStructureRegistry()
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder == nil then
		return nil
	end

	local structuresFolder = assetsFolder:FindFirstChild("Structures")
	if structuresFolder == nil or not structuresFolder:IsA("Folder") then
		return nil
	end

	return AssetFetcher.CreateStructureRegistry(structuresFolder)
end

local structureRegistry = _CreateStructureRegistry()

local function _FindTemplateModel(structureType: string): Model?
	if structureRegistry == nil then
		return nil
	end

	return structureRegistry:GetStructureModel(structureType)
end

function PlacementGhostModel.new(structureType: string)
	local model = _FindTemplateModel(structureType)
	if model == nil then
		error("PlacementGhostModel: missing structure model for type '" .. structureType .. "'")
	end

	_ApplyGhostStyle(model)

	if model.PrimaryPart == nil then
		local primaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		if primaryPart ~= nil then
			model.PrimaryPart = primaryPart
		end
	end

	model.Parent = Workspace

	local self = setmetatable({}, PlacementGhostModel)
	self._model = model
	return self
end

function PlacementGhostModel:MoveTo(worldPos: Vector3)
	self._model:PivotTo(CFrame.new(worldPos))
end

function PlacementGhostModel:SetValid(isValid: boolean)
	local tint = if isValid then VALID_COLOR else INVALID_COLOR
	for _, descendant in ipairs(self._model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = tint
		end
	end
end

function PlacementGhostModel:Destroy()
	if self._model ~= nil then
		self._model:Destroy()
		self._model = nil
	end
end

return PlacementGhostModel
