--!strict

--[=[
	@class VillagerModelFactory
	Creates and manages Roblox model instances for villagers; handles rigging, collision, and cleanup.
	@server
]=]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VillagerConfig = require(ReplicatedStorage.Contexts.Villager.Config.VillagerConfig)

local VillagerModelFactory = {}
VillagerModelFactory.__index = VillagerModelFactory

export type TVillagerModelFactory = typeof(setmetatable({} :: {
	ModelsFolder: Folder?,
	AnimationsFolder: Folder?,
	VillagersFolder: Folder,
}, VillagerModelFactory))

function VillagerModelFactory.new(modelsFolder: Folder?, animationsFolder: Folder?): TVillagerModelFactory
	local self = setmetatable({}, VillagerModelFactory)
	self.ModelsFolder = modelsFolder
	self.AnimationsFolder = animationsFolder
	self.VillagersFolder = self:_FindOrCreateFolder(Workspace, "Villagers")
	return self
end

function VillagerModelFactory:Init(_registry: any)
	self:_EnsureCollisionGroupConfig()
end

--[=[
	Creates a new villager model instance from template, configured with attributes and collision.
	@within VillagerModelFactory
	@param modelKey string -- Model template key (archetype)
	@param villagerId string -- Unique villager ID
	@param displayName string -- Display name for the villager
	@return Model -- Configured villager model
]=]
function VillagerModelFactory:CreateVillagerModel(modelKey: string, villagerId: string, displayName: string): Model
	local model = self:_CloneConfiguredModel(modelKey)
	model.Name = "Villager_" .. villagerId
	model:SetAttribute("VillagerId", villagerId)
	model:SetAttribute("DisplayName", displayName)

	-- Attach animations folder reference if available
	if self.AnimationsFolder then
		local folderRef = Instance.new("ObjectValue")
		folderRef.Name = "AnimationsFolder"
		folderRef.Value = self.AnimationsFolder
		folderRef.Parent = model
	end

	self:_ApplyCollisionGroup(model)
	self:_AttachPrompt(model)
	model.Parent = self.VillagersFolder
	CollectionService:AddTag(model, "Villager")
	return model
end

--[=[
	Updates the model's position in the world.
	@within VillagerModelFactory
	@param model Model -- Villager model
	@param cframe CFrame -- New position
]=]
function VillagerModelFactory:UpdatePosition(model: Model, cframe: CFrame)
	if model.PrimaryPart then
		model:PivotTo(cframe)
	end
end

--[=[
	Destroys a villager model.
	@within VillagerModelFactory
	@param model Model -- Model to remove
]=]
function VillagerModelFactory:DestroyModel(model: Model)
	model:Destroy()
end

-- Clones configured model from templates; falls back to Default, then procedurally generated.
function VillagerModelFactory:_CloneConfiguredModel(modelKey: string): Model
	local configuredModel = self:_FindModel(modelKey) or self:_FindModel("Default")
	if configuredModel then
		local clone = configuredModel:Clone()
		self:_EnsurePrimaryPart(clone)
		return clone
	end

	return self:_CreateFallbackModel()
end

-- Looks up model template by key; if folder, returns first child model.
function VillagerModelFactory:_FindModel(modelKey: string): Model?
	if not self.ModelsFolder then
		return nil
	end

	local child = self.ModelsFolder:FindFirstChild(modelKey)
	if not child then
		return nil
	end

	if child:IsA("Model") then
		return child
	end

	if child:IsA("Folder") then
		return child:FindFirstChildWhichIsA("Model")
	end

	return nil
end

-- Creates a basic fallback model with root, body, and humanoid if templates unavailable.
function VillagerModelFactory:_CreateFallbackModel(): Model
	local model = Instance.new("Model")
	model.Name = "VillagerFallback"

	-- Root part for pathfinding and positioning
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model

	-- Body part for visibility
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 3, 1)
	body.Position = Vector3.new(0, 1.5, 0)
	body.Parent = model

	-- Weld body to root
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = root

	-- Humanoid for compatibility with pathfinding/animations
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

-- Ensures model has PrimaryPart set (fallback to HumanoidRootPart).
function VillagerModelFactory:_EnsurePrimaryPart(model: Model)
	if model.PrimaryPart then
		return
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
	end
end

-- Registers villager collision group and configures self-collision based on config.
function VillagerModelFactory:_EnsureCollisionGroupConfig()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(VillagerConfig.COLLISION_GROUP)
	end)

	PhysicsService:CollisionGroupSetCollidable(
		VillagerConfig.COLLISION_GROUP,
		VillagerConfig.COLLISION_GROUP,
		VillagerConfig.COLLIDES_WITH_VILLAGERS
	)
end

-- Assigns all parts in model to villager collision group.
function VillagerModelFactory:_ApplyCollisionGroup(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = VillagerConfig.COLLISION_GROUP
		end
	end
end

-- Attaches proximity prompt to model's primary part if not already present.
function VillagerModelFactory:_AttachPrompt(model: Model)
	local root = model.PrimaryPart
	if not root then
		return
	end

	local prompt = root:FindFirstChild("VillagerPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		return
	end

	-- Create "Talk" prompt for players to interact with villager
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = "VillagerPrompt"
	proximityPrompt.ActionText = "Talk"
	proximityPrompt.ObjectText = "Villager"
	proximityPrompt.HoldDuration = 0
	proximityPrompt.MaxActivationDistance = 10
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.Parent = root
end

-- Finds or creates a folder under parent.
function VillagerModelFactory:_FindOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

return VillagerModelFactory
