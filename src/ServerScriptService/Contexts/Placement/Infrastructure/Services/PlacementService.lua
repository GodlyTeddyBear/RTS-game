--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Result = require(ReplicatedStorage.Utilities.Result)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local PlacementFootprintResolver = require(ReplicatedStorage.Contexts.Placement.PlacementFootprintResolver)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local StructureSpecs = require(ServerScriptService.Contexts.Structure.StructureDomain.Specs.StructureSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Ensure = Result.Ensure

type SpawnedStructure = Model
type GridCoord = { GridId: string, Row: number, Col: number }

local function _ResolveGridSpec(gridSpecs: { any }, gridId: string): any?
	for _, spec in ipairs(gridSpecs) do
		if spec.GridId == gridId then
			return spec
		end
	end
	return nil
end

local function _GridCoordToWorldFromSpec(spec: any, row: number, col: number): Vector3
	local localX = -spec.GridSize.X * 0.5 + spec.TileSize * 0.5 + (col - 1) * spec.TileSize
	local localZ = -spec.GridSize.Z * 0.5 + spec.TileSize * 0.5 + (row - 1) * spec.TileSize
	return spec.GridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

--[=[
	@class PlacementService
	Spawns and destroys physical structures in Workspace.
	@server
]=]
local PlacementService = {}
PlacementService.__index = PlacementService
local GROUND_FLAT_DOT = 1

--[=[
	Creates a new placement service.
	@within PlacementService
	@return PlacementService -- The new service instance.
]=]
-- The service keeps runtime instance bookkeeping in memory only.
function PlacementService.new()
	local self = setmetatable({}, PlacementService)
	self._folder = nil :: Folder?
	self._structuresFolder = nil :: Folder?
	self._animationsFolder = nil :: Folder?
	self._instanceMap = {} :: { [number]: SpawnedStructure }
	self._nextId = 1
	self._worldContext = nil :: any
	self._renderContext = nil :: any
	self._validatedStructureTypes = {} :: { [string]: boolean }
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
	end

	local animationsFolder = assets and assets:FindFirstChild("Animations")
	if animationsFolder and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end
end

function PlacementService:Start(registry: any, _name: string)
	self._worldContext = registry:Get("WorldContext")
	self._renderContext = registry:Get("RenderContext")
end

function PlacementService:_ResolveFirstNonGridHit(
	origin: Vector3,
	direction: Vector3,
	baseExclude: { Instance }?
): RaycastResult?
	local excludedInstances = {}
	if baseExclude ~= nil then
		for _, instance in ipairs(baseExclude) do
			table.insert(excludedInstances, instance)
		end
	end

	while true do
		local hit = SpatialQuery.Raycast(origin, direction, SpatialQuery.CreateRaycastOptions({
			FilterType = Enum.RaycastFilterType.Exclude,
			FilterDescendantsInstances = excludedInstances,
			RespectCanCollide = true,
		}))
		if hit == nil then
			return nil
		end

		if hit.Instance.Name ~= WorldConfig.GRID_PART_NAME then
			return hit
		end

		table.insert(excludedInstances, hit.Instance)
	end
end

function PlacementService:ResolveGroundPointFromFootprint(
	anchorCoord: GridCoord,
	widthTiles: number,
	depthTiles: number
): Result.Result<Vector3>
	local gridSpecsResult = self._worldContext:GetGridSpecList()
	if not gridSpecsResult.success then
		return Err("GroundCoordUnavailable", Errors.INVALID_COORD, {
			GridId = anchorCoord.GridId,
			Row = anchorCoord.Row,
			Col = anchorCoord.Col,
		})
	end

	local gridSpec = _ResolveGridSpec(gridSpecsResult.value, anchorCoord.GridId)
	if gridSpec == nil then
		return Err("GroundCoordUnavailable", Errors.INVALID_COORD, {
			GridId = anchorCoord.GridId,
			Row = anchorCoord.Row,
			Col = anchorCoord.Col,
		})
	end

	local centerRow = anchorCoord.Row + ((depthTiles - 1) * 0.5)
	local centerCol = anchorCoord.Col + ((widthTiles - 1) * 0.5)
	local tileWorldPos = _GridCoordToWorldFromSpec(gridSpec, centerRow, centerCol)
	local raycastConfig = PlacementConfig.GROUND_RAYCAST
	local rayOrigin = Vector3.new(tileWorldPos.X, tileWorldPos.Y + raycastConfig.HeightOffset, tileWorldPos.Z)
	local rayDirection = Vector3.new(0, -raycastConfig.Length, 0)
	local hit = self:_ResolveFirstNonGridHit(rayOrigin, rayDirection, nil)
	if hit == nil then
		return Err("PlacementGroundHitMissing", Errors.NO_GROUND_HIT, {
			GridId = anchorCoord.GridId,
			Row = anchorCoord.Row,
			Col = anchorCoord.Col,
		})
	end

	local hitNormal = hit.Normal
	if raycastConfig.RequirePerfectlyFlat and hitNormal:Dot(Vector3.yAxis) ~= GROUND_FLAT_DOT then
		return Err("InvalidGroundSlope", Errors.INVALID_GROUND_SLOPE, {
			GridId = anchorCoord.GridId,
			Row = anchorCoord.Row,
			Col = anchorCoord.Col,
			NormalX = hitNormal.X,
			NormalY = hitNormal.Y,
			NormalZ = hitNormal.Z,
		})
	end

	return Ok(hit.Position)
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

	if self._renderContext == nil then
		Ensure(structureType == MiningConfig.EXTRACTOR_STRUCTURE_TYPE, "TemplateNotFound", Errors.TEMPLATE_NOT_FOUND, {
			structureType = structureType,
			requiredPath = "ReplicatedStorage.Assets.Structures",
		})
		return _CreateExtractorFallbackModel()
	end

	local structureResult = self._renderContext:GetStructureModel(structureType)
	local model = if structureResult.success then structureResult.value else nil
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
function PlacementService:SpawnStructure(
	structureType: string,
	worldPos: Vector3,
	rotationQuarterTurns: number?
): Result.Result<number>
	if StructureSpecs.IsValidStructureType(structureType) then
		local instanceId = self._nextId
		self._nextId += 1
		return Ok(instanceId)
	end

	-- Models and parts both support :PivotTo, which keeps the spawn path generic.
	local spawnModel = self:_ResolveSpawnModel(structureType)
	_PrepareStructureAnimationRuntime(spawnModel, self._animationsFolder)
	local normalizedTurns = PlacementFootprintResolver.NormalizeRotationQuarterTurns(rotationQuarterTurns)
	if normalizedTurns ~= 0 then
		ModelPlus.RotateYaw(spawnModel, math.rad(normalizedTurns * 90))
	end
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
	if self._validatedStructureTypes[structureType] == true then
		return Ok(nil)
	end

	local validated = false
	if structureType == MiningConfig.EXTRACTOR_STRUCTURE_TYPE then
		validated = true
	elseif self._renderContext ~= nil then
		local existsResult = self._renderContext:StructureModelExists(structureType)
		local defaultExistsResult = self._renderContext:StructureModelExists("Default")
		if (existsResult.success and existsResult.value == true) or (defaultExistsResult.success and defaultExistsResult.value == true) then
			validated = true
		end
	end

	if not validated then
		self:_ResolveSpawnModel(structureType)
	end

	self._validatedStructureTypes[structureType] = true
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
