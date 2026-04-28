--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Result = require(ReplicatedStorage.Utilities.Result)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local StructureSpecs = require(ServerScriptService.Contexts.Structure.StructureDomain.Specs.StructureSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

type SpawnedStructure = Model

--[=[
	@class PlacementService
	Spawns and destroys physical structures in Workspace.
	@server
]=]
local PlacementService = {}
PlacementService.__index = PlacementService

--[=[
	Creates a new placement service.
	@within PlacementService
	@return PlacementService -- The new service instance.
]=]
-- The service keeps runtime instance bookkeeping in memory only.
function PlacementService.new()
	local self = setmetatable({}, PlacementService)
	self._folder = nil :: Folder?
	self._structureRegistry = nil :: any
	self._structuresFolder = nil :: Folder?
	self._animationsFolder = nil :: Folder?
	self._instanceMap = {} :: { [number]: SpawnedStructure }
	self._nextId = 1
	return self
end

--[=[
	Initializes the workspace placement folder.
	@within PlacementService
	@param _registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
-- Ensure the workspace folder exists before any structure spawns can happen.
function PlacementService:Init(_registry: any, _name: string)
	local existing = Workspace:FindFirstChild(PlacementConfig.PLACEMENT_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		self._folder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = PlacementConfig.PLACEMENT_FOLDER_NAME
		folder.Parent = Workspace
		self._folder = folder
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local structuresFolder = assets and assets:FindFirstChild("Structures")
	if structuresFolder and structuresFolder:IsA("Folder") then
		self._structuresFolder = structuresFolder
		self._structureRegistry = AssetFetcher.CreateStructureRegistry(structuresFolder)
	end

	local animationsFolder = assets and assets:FindFirstChild("Animations")
	if animationsFolder and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end
end

local function _EnsureAnimationsFolderValue(model: Model, animationsFolder: Folder?)
	local animationsFolderRef = model:FindFirstChild("AnimationsFolder")
	if animationsFolderRef ~= nil and not animationsFolderRef:IsA("ObjectValue") then
		animationsFolderRef:Destroy()
		animationsFolderRef = nil
	end

	if animationsFolderRef == nil then
		animationsFolderRef = Instance.new("ObjectValue")
		animationsFolderRef.Name = "AnimationsFolder"
		animationsFolderRef.Parent = model
	end

	if animationsFolder ~= nil then
		(animationsFolderRef :: ObjectValue).Value = animationsFolder
	end
end

local function _EnsureHumanoid(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		return
	end

	humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
end

local function _PrepareStructureAnimationRuntime(model: Model, animationsFolder: Folder?)
	_EnsureHumanoid(model)
	_EnsureAnimationsFolderValue(model, animationsFolder)

	if model:GetAttribute("AnimationState") == nil then
		model:SetAttribute("AnimationState", "Idle")
	end
	if model:GetAttribute("AnimationLooping") == nil then
		model:SetAttribute("AnimationLooping", true)
	end
end

local function _CreateExtractorFallbackModel(): Model
	local model = Instance.new("Model")
	model.Name = MiningConfig.EXTRACTOR_STRUCTURE_TYPE

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = true
	base.Size = Vector3.new(5, 1, 5)
	base.Color = Color3.fromRGB(78, 83, 92)
	base.Material = Enum.Material.Metal
	base.Parent = model

	local drill = Instance.new("Part")
	drill.Name = "ExtractorCore"
	drill.Anchored = true
	drill.CanCollide = true
	drill.Size = Vector3.new(2, 4, 2)
	drill.Position = Vector3.new(0, 2.5, 0)
	drill.Color = Color3.fromRGB(202, 170, 76)
	drill.Material = Enum.Material.DiamondPlate
	drill.Parent = model

	model.PrimaryPart = base
	return model
end

local function _HasExplicitStructureTemplate(structuresFolder: Folder?, structureType: string): boolean
	if structuresFolder == nil then
		return false
	end

	local typeNode = structuresFolder:FindFirstChild(structureType)
	if typeNode == nil then
		return false
	end

	if typeNode:IsA("Model") then
		return true
	end

	return typeNode:IsA("Folder") and typeNode:FindFirstChildWhichIsA("Model") ~= nil
end

function PlacementService:_ResolveSpawnModel(structureType: string): SpawnedStructure
	if
		structureType == MiningConfig.EXTRACTOR_STRUCTURE_TYPE
		and not _HasExplicitStructureTemplate(self._structuresFolder, structureType)
	then
		return _CreateExtractorFallbackModel()
	end

	if self._structureRegistry == nil then
		Ensure(structureType == MiningConfig.EXTRACTOR_STRUCTURE_TYPE, "TemplateNotFound", Errors.TEMPLATE_NOT_FOUND, {
			structureType = structureType,
			requiredPath = "ReplicatedStorage.Assets.Structures",
		})
		return _CreateExtractorFallbackModel()
	end

	local model = self._structureRegistry:GetStructureModel(structureType)
	if model == nil and structureType == MiningConfig.EXTRACTOR_STRUCTURE_TYPE then
		return _CreateExtractorFallbackModel()
	end

	Ensure(model ~= nil, "TemplateNotFound", Errors.TEMPLATE_NOT_FOUND, {
		structureType = structureType,
		requiredPath = "ReplicatedStorage.Assets.Structures",
		fallback = "Default",
	})

	return model
end

--[=[
	Spawns a structure model or part at the requested world position.
	@within PlacementService
	@param structureType string -- The placement key.
	@param worldPos Vector3 -- The tile world position.
	@return Result.Result<number> -- The runtime instance identifier.
]=]
-- Clone the configured template, place it at the tile position, and remember the runtime id.
function PlacementService:SpawnStructure(structureType: string, worldPos: Vector3): Result.Result<number>
	if StructureSpecs.IsValidStructureType(structureType) then
		local instanceId = self._nextId
		self._nextId += 1
		return Ok(instanceId)
	end

	-- Models and parts both support :PivotTo, which keeps the spawn path generic.
	local spawnModel = self:_ResolveSpawnModel(structureType)
	_PrepareStructureAnimationRuntime(spawnModel, self._animationsFolder)
	ModelPlus.MoveBottomAligned(spawnModel, worldPos)

	local instanceId = self._nextId
	self._nextId += 1
	spawnModel:SetAttribute("PlacementInstanceId", instanceId)
	spawnModel.Parent = self._folder
	EntityCollisionService:ApplyStructureModel(spawnModel)
	self._instanceMap[instanceId] = spawnModel

	return Ok(instanceId)
end

--[=[
	Validates whether the configured structure template exists and is spawnable.
	@within PlacementService
	@param structureType string -- The placement key.
	@return Result.Result<nil> -- `Ok(nil)` when a spawnable template exists.
]=]
function PlacementService:ValidateTemplate(structureType: string): Result.Result<nil>
	self:_ResolveSpawnModel(structureType):Destroy()
	return Ok(nil)
end

--[=[
	Removes a single spawned runtime instance.
	@within PlacementService
	@param instanceId number -- The runtime instance identifier.
]=]
-- Destroy a single runtime instance when rollback or manual cleanup needs to remove it.
function PlacementService:DestroyStructure(instanceId: number)
	local instance = self._instanceMap[instanceId]
	if instance == nil then
		return
	end

	instance:Destroy()
	self._instanceMap[instanceId] = nil
end

function PlacementService:GetStructureInstance(instanceId: number): Model?
	local instance = self._instanceMap[instanceId]
	if instance ~= nil and instance:IsA("Model") then
		return instance
	end

	return nil
end

--[=[
	Removes every spawned structure and resets the instance counter.
	@within PlacementService
]=]
-- Reset the runtime cache so a new run starts from a clean workspace state.
function PlacementService:DestroyAll()
	for instanceId, instance in self._instanceMap do
		instance:Destroy()
		self._instanceMap[instanceId] = nil
	end

	self._nextId = 1
end

return PlacementService
