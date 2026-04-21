--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)

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

local function _CreatePlaceholderModel(): Model
	local model = Instance.new("Model")
	model.Name = "PlacementGhostPlaceholder"

	local part = Instance.new("Part")
	part.Name = "GhostPart"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = VALID_COLOR
	part.Transparency = 0.5
	part.Size = Vector3.new(6, 4, 6)
	part.Parent = model

	return model
end

local function _FindTemplateModel(structureType: string): Model?
	local templateName = PlacementConfig.STRUCTURE_TEMPLATES[structureType]
	if templateName == nil then
		return nil
	end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder == nil then
		return nil
	end

	local structuresFolder = assetsFolder:FindFirstChild("Structures")
	if structuresFolder == nil then
		return nil
	end

	local template = structuresFolder:FindFirstChild(templateName)
	if template == nil or not template:IsA("Model") then
		return nil
	end

	return template:Clone()
end

function PlacementGhostModel.new(structureType: string)
	local model = _FindTemplateModel(structureType)
	if model == nil then
		model = _CreatePlaceholderModel()
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
