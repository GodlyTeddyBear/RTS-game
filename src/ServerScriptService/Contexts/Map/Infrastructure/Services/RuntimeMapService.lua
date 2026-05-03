--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local MapConfig = require(ReplicatedStorage.Contexts.Map.Config.MapConfig)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Ensure = Result.Ensure
local fromPcall = Result.fromPcall

type ZoneMap = { [string]: Instance }

--[=[
	@class RuntimeMapService
	Owns cloning, placement, and cleanup of the runtime map model.
	@server
]=]
local RuntimeMapService = {}
RuntimeMapService.__index = RuntimeMapService

local GRID_ID_ATTRIBUTE = "GridId"
local GRID_QUANTIZATION_SCALE = 1000

local function _ResolvePath(root: Instance, path: string): Instance?
	local current = root
	for segment in string.gmatch(path, "[^%.]+") do
		local child = current:FindFirstChild(segment)
		if child == nil then
			return nil
		end
		current = child
	end
	return current
end

local function _QuantizeNumber(value: number): number
	return math.floor(value * GRID_QUANTIZATION_SCALE + 0.5)
end

local function _GetInstancePath(instance: Instance): string
	local segments = {}
	local current = instance
	while current ~= nil do
		table.insert(segments, 1, current.Name)
		current = current.Parent
	end
	return table.concat(segments, ".")
end

local function _BuildGridSortTieBreaker(gridPart: BasePart): string
	local position = gridPart.Position
	local size = gridPart.Size
	local orientation = gridPart.Orientation

	return table.concat({
		tostring(_QuantizeNumber(position.X)),
		tostring(_QuantizeNumber(position.Y)),
		tostring(_QuantizeNumber(position.Z)),
		tostring(_QuantizeNumber(size.X)),
		tostring(_QuantizeNumber(size.Y)),
		tostring(_QuantizeNumber(size.Z)),
		tostring(_QuantizeNumber(orientation.X)),
		tostring(_QuantizeNumber(orientation.Y)),
		tostring(_QuantizeNumber(orientation.Z)),
	}, "|")
end

local function _IsGuidLike(value: string): boolean
	return string.match(value, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function _CreateUniqueGuid(usedGridIds: { [string]: boolean }): string
	local guid = HttpService:GenerateGUID(false)
	while usedGridIds[guid] == true do
		guid = HttpService:GenerateGUID(false)
	end
	return guid
end

local function _SortGridPartsByDeterministicOrder(gridParts: { BasePart })
	local stableOrderByPart = {} :: { [BasePart]: number }
	for index, gridPart in ipairs(gridParts) do
		stableOrderByPart[gridPart] = index
	end

	table.sort(gridParts, function(left: BasePart, right: BasePart): boolean
		local leftPath = _GetInstancePath(left)
		local rightPath = _GetInstancePath(right)
		if leftPath ~= rightPath then
			return leftPath < rightPath
		end

		local leftTieBreaker = _BuildGridSortTieBreaker(left)
		local rightTieBreaker = _BuildGridSortTieBreaker(right)
		if leftTieBreaker ~= rightTieBreaker then
			return leftTieBreaker < rightTieBreaker
		end

		local leftStableOrder = stableOrderByPart[left] or 0
		local rightStableOrder = stableOrderByPart[right] or 0
		return leftStableOrder < rightStableOrder
	end)
end

local function _ResolveZonePath(root: Instance, path: string): Instance?
	local resolved = _ResolvePath(root, path)
	if resolved ~= nil then
		return resolved
	end

	if string.sub(path, 1, 5) == "Game." then
		return _ResolvePath(root, string.sub(path, 6))
	end

	return _ResolvePath(root, ("Game.%s"):format(path))
end

local function _ExtractModel(instance: Instance?): Model?
	if instance == nil then
		return nil
	end

	if instance:IsA("Model") then
		return instance
	end

	if instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end

	return nil
end

--[=[
	Creates the runtime map service wrapper.
	@within RuntimeMapService
	@return RuntimeMapService -- The new runtime map service instance.
]=]
function RuntimeMapService.new()
	local self = setmetatable({}, RuntimeMapService)
	self._entityFactory = nil
	self._activeRuntimeModel = nil :: Model?
	return self
end

--[=[
	Binds the map entity factory used to register the runtime map model.
	@within RuntimeMapService
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function RuntimeMapService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("MapEntityFactory")
end

--[=[
	Creates a fresh runtime map model, relocates it, and registers its zones.
	@within RuntimeMapService
	@return Result.Result<boolean> -- Whether the runtime map was created successfully.
]=]
function RuntimeMapService:CreateOrReplaceRuntimeMap(): Result.Result<boolean>
	-- Clone the configured template before any world state is mutated.
	local templateResult = self:_CloneTemplateModel(MapConfig.TEMPLATE_NAME)
	if not templateResult.success then
		return templateResult
	end
	-- Relocate the cloned map to its configured runtime target.
	local runtimeMapModel = templateResult.value
	local relocateResult = self:_RelocateRuntimeMap(runtimeMapModel)
	if not relocateResult.success then
		runtimeMapModel:Destroy()
		return relocateResult
	end

	self:_AssignRuntimePlacementGridIds(runtimeMapModel)
	-- Discover map zones before replacing the live runtime model.
	local zonesResult = self:_DiscoverZones(runtimeMapModel)
	if not zonesResult.success then
		runtimeMapModel:Destroy()
		return zonesResult
	end

	-- Clear any previous runtime map so the new instance becomes authoritative.
	self:CleanupRuntimeMap()

	-- Attach the new model to the workspace container after validation succeeds.
	local mapContainer = Workspace:FindFirstChild(MapConfig.WORKSPACE_MAP_CONTAINER_NAME)
	Ensure(mapContainer, "MissingWorkspaceMapContainer", Errors.MISSING_WORKSPACE_MAP_CONTAINER)

	local gameContainer = mapContainer:FindFirstChild(MapConfig.WORKSPACE_GAME_CONTAINER_NAME)
	Ensure(gameContainer, "MissingWorkspaceGameContainer", Errors.MISSING_WORKSPACE_GAME_CONTAINER)

	local existingRuntimeMap = gameContainer:FindFirstChild(MapConfig.RUNTIME_MAP_NAME)
	if existingRuntimeMap and existingRuntimeMap:IsA("Model") then
		existingRuntimeMap:Destroy()
	end

	runtimeMapModel.Name = MapConfig.RUNTIME_MAP_NAME
	runtimeMapModel.Parent = gameContainer
	self._activeRuntimeModel = runtimeMapModel

	-- Register the runtime map root so ECS queries can resolve zones and base markers.
	local mapId = ("RuntimeMap_%d"):format(math.floor(os.clock() * 1000))
	self._entityFactory:CreateMapRoot(mapId, MapConfig.TEMPLATE_NAME, runtimeMapModel, zonesResult.value)

	return Ok(true)
end

function RuntimeMapService:_AssignRuntimePlacementGridIds(runtimeMapModel: Model)
	local placementGridsZonePath = MapConfig.ZONE_PATHS.PlacementGrids
	if type(placementGridsZonePath) ~= "string" or #placementGridsZonePath == 0 then
		Result.MentionError(
			"Map:GridIdGuidAssigned",
			"PlacementGrids zone path is missing or invalid; skipping runtime GridId GUID assignment",
			{
				ZonePathType = type(placementGridsZonePath),
			},
			"GridIdGuidPathInvalid"
		)
		return
	end

	local placementGridsZone = _ResolveZonePath(runtimeMapModel, placementGridsZonePath)
	if placementGridsZone == nil then
		Result.MentionError(
			"Map:GridIdGuidAssigned",
			"PlacementGrids zone was not found on runtime map; skipping runtime GridId GUID assignment",
			{
				ZonePath = placementGridsZonePath,
			},
			"GridIdGuidZoneMissing"
		)
		return
	end

	local gridParts = {} :: { BasePart }
	if placementGridsZone:IsA("BasePart") and placementGridsZone.Name == WorldConfig.GRID_PART_NAME then
		table.insert(gridParts, placementGridsZone)
	end

	for _, descendant in ipairs(placementGridsZone:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == WorldConfig.GRID_PART_NAME then
			table.insert(gridParts, descendant)
		end
	end

	if #gridParts == 0 then
		Result.MentionError("Map:GridIdGuidAssigned", "No PlacementGrid parts were found in PlacementGrids zone", {
			ZonePath = placementGridsZonePath,
		}, "GridIdGuidNoGridParts")
		return
	end

	_SortGridPartsByDeterministicOrder(gridParts)

	local usedGridIds = {} :: { [string]: boolean }
	for _, gridPart in ipairs(gridParts) do
		local authoredId = gridPart:GetAttribute(GRID_ID_ATTRIBUTE)
		if type(authoredId) == "string" and #authoredId > 0 and _IsGuidLike(authoredId) then
			usedGridIds[authoredId] = true
		end
	end

	local runtimeGuidAssignedCount = 0
	for index, gridPart in ipairs(gridParts) do
		local authoredId = gridPart:GetAttribute(GRID_ID_ATTRIBUTE)
		if type(authoredId) == "string" and #authoredId > 0 and _IsGuidLike(authoredId) then
			continue
		end

		local resolvedId = _CreateUniqueGuid(usedGridIds)

		gridPart:SetAttribute(GRID_ID_ATTRIBUTE, resolvedId)
		usedGridIds[resolvedId] = true
		runtimeGuidAssignedCount += 1

		Result.MentionEvent("Map:GridIdGuidAssigned", "Assigned runtime GUID GridId for PlacementGrid", {
			GridId = resolvedId,
			GridPath = _GetInstancePath(gridPart),
			GridIndex = index,
			PreviousGridId = authoredId,
		})
	end

	if runtimeGuidAssignedCount > 0 then
		Result.MentionEvent(
			"Map:GridIdGuidAssigned",
			"PlacementGrid GridIds were missing or non-GUID; runtime GUIDs were assigned",
			{
				AssignedCount = runtimeGuidAssignedCount,
			}
		)
		Result.MentionError("Map:GridIdGuidAssigned", "Assigned runtime GUID GridIds for PlacementGrids", {
			AssignedCount = runtimeGuidAssignedCount,
			TotalGridParts = #gridParts,
		}, "GridIdGuidAssigned")
	else
		Result.MentionError(
			"Map:GridIdGuidAssigned",
			"All PlacementGrid parts already had GUID GridIds; no runtime assignment was needed",
			{
				TotalGridParts = #gridParts,
			},
			"GridIdGuidNoOp"
		)
	end
end

--[=[
	Cleans up the active runtime map model and clears the registered map entity.
	@within RuntimeMapService
	@return Result.Result<boolean> -- Whether the runtime map cleanup succeeded.
]=]
function RuntimeMapService:CleanupRuntimeMap(): Result.Result<boolean>
	-- Remove the ECS entity first so downstream queries stop seeing stale runtime map state.
	self._entityFactory:DeleteActiveMap()

	-- Destroy the in-memory runtime model if this context still owns one.
	local model = self._activeRuntimeModel
	if model and model.Parent then
		model:Destroy()
	end

	-- Remove any leftover workspace copy in case the active model was replaced elsewhere.
	local mapContainer = Workspace:FindFirstChild(MapConfig.WORKSPACE_MAP_CONTAINER_NAME)
	if mapContainer then
		local gameContainer = mapContainer:FindFirstChild(MapConfig.WORKSPACE_GAME_CONTAINER_NAME)
		if gameContainer then
			local runtimeMap = gameContainer:FindFirstChild(MapConfig.RUNTIME_MAP_NAME)
			if runtimeMap and runtimeMap:IsA("Model") then
				runtimeMap:Destroy()
			end
		end
	end

	-- Clear the cached handle last so cleanup remains idempotent.
	self._activeRuntimeModel = nil
	return Ok(true)
end

-- Clones the configured map template from ReplicatedStorage assets.
function RuntimeMapService:_CloneTemplateModel(templateName: string): Result.Result<Model>
	-- Resolve the map assets folder hierarchy before touching the template selection.
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	Ensure(assetsFolder, "MissingAssetsFolder", Errors.MISSING_ASSETS_FOLDER)

	local mapsFolder = assetsFolder:FindFirstChild("Maps")
	Ensure(mapsFolder, "MissingMapsFolder", Errors.MISSING_MAPS_FOLDER)

	-- Fall back to the default template so the runtime map can still build when the named variant is absent.
	local templateNode = mapsFolder:FindFirstChild(templateName) or mapsFolder:FindFirstChild("Default")
	if templateNode == nil then
		return Err("MapTemplateNotFound", Errors.MAP_TEMPLATE_NOT_FOUND, { Template = templateName })
	end

	-- Extract the actual model before cloning so folders can wrap the template without changing call sites.
	local templateModel = _ExtractModel(templateNode)
	Ensure(templateModel, "MapTemplateInvalid", Errors.MAP_TEMPLATE_INVALID, { Template = templateNode.Name })

	return Ok(templateModel:Clone())
end

-- Discovers configured zones and validates that every required zone exists.
function RuntimeMapService:_DiscoverZones(runtimeMapModel: Model): Result.Result<ZoneMap>
	local zonesByName = {} :: ZoneMap

	-- Resolve every configured zone path into live instances under the cloned runtime map.
	for zoneName, zonePath in pairs(MapConfig.ZONE_PATHS) do
		local resolved = _ResolveZonePath(runtimeMapModel, zonePath)
		if resolved ~= nil then
			zonesByName[zoneName] = resolved
		end
	end

	-- Validate that required zones were actually present before the runtime map is published.
	for _, requiredZone in ipairs(MapConfig.REQUIRED_ZONES) do
		local zone = zonesByName[requiredZone]
		if zone == nil then
			return Err("RequiredZoneMissing", Errors.REQUIRED_ZONE_MISSING, { ZoneName = requiredZone })
		end
	end

	return Ok(zonesByName)
end

-- Repositions the runtime map to its configured world target.
function RuntimeMapService:_RelocateRuntimeMap(runtimeMapModel: Model): Result.Result<boolean>
	-- Resolve the target position first so relocation fails before touching the model pivot.
	local targetPositionResult = self:_ResolveRuntimeMapTargetPosition()
	if not targetPositionResult.success then
		return targetPositionResult
	end

	-- Preserve the current orientation while moving the clone to the configured runtime position.
	local targetPosition = targetPositionResult.value
	local pivotResult = fromPcall("RelocateRuntimeMapFailed", function()
		local targetPivot = ModelPlus.BuildPivotAtPosition(runtimeMapModel, targetPosition)
		runtimeMapModel:PivotTo(targetPivot)
	end)
	if not pivotResult.success then
		return Err("RelocateRuntimeMapFailed", Errors.FAILED_TO_RELOCATE_RUNTIME_MAP, {
			CauseMessage = pivotResult.message,
		})
	end

	return Ok(true)
end

-- Resolves the configured runtime map target position or validates an override.
function RuntimeMapService:_ResolveRuntimeMapTargetPosition(configuredPositionOverride: any?): Result.Result<Vector3>
	-- Allow a caller override during tests while defaulting to the configured runtime target.
	local configuredPosition = configuredPositionOverride
	if configuredPosition == nil then
		configuredPosition = MapConfig.RUNTIME_MAP_TARGET_POSITION
	end

	if typeof(configuredPosition) ~= "Vector3" then
		return Err("InvalidRuntimeMapTargetPosition", Errors.INVALID_RUNTIME_MAP_TARGET_POSITION, {
			ConfigValueType = typeof(configuredPosition),
		})
	end

	return Ok(configuredPosition)
end

--[=[
	Returns the active runtime map model, if one has been created.
	@within RuntimeMapService
	@return Model? -- The active runtime map model, if present.
]=]
function RuntimeMapService:GetActiveRuntimeModel(): Model?
	return self._activeRuntimeModel
end

return RuntimeMapService
