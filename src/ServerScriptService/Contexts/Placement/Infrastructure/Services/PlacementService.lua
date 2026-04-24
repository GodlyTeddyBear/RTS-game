--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Result = require(ReplicatedStorage.Utilities.Result)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
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
		self._structureRegistry = AssetFetcher.CreateStructureRegistry(structuresFolder)
	end
end

function PlacementService:_ResolveSpawnModel(structureType: string): SpawnedStructure
	Ensure(self._structureRegistry ~= nil, "TemplateNotFound", Errors.TEMPLATE_NOT_FOUND, {
		structureType = structureType,
		requiredPath = "ReplicatedStorage.Assets.Structures",
	})

	local model = self._structureRegistry:GetStructureModel(structureType)
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
	-- Models and parts both support :PivotTo, which keeps the spawn path generic.
	local spawnModel = self:_ResolveSpawnModel(structureType)
	spawnModel:PivotTo(CFrame.new(worldPos))

	local instanceId = self._nextId
	self._nextId += 1
	spawnModel:SetAttribute("PlacementInstanceId", instanceId)
	spawnModel.Parent = self._folder
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
