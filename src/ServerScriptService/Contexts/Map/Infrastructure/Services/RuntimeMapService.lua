--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Result = require(ReplicatedStorage.Utilities.Result)
local MapConfig = require(ReplicatedStorage.Contexts.Map.Config.MapConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Ensure = Result.Ensure
local fromPcall = Result.fromPcall

type ZoneMap = { [string]: Instance }

local RuntimeMapService = {}
RuntimeMapService.__index = RuntimeMapService

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

local function _BuildCFrameWithPosition(source: CFrame, targetPosition: Vector3): CFrame
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = source:GetComponents()
	return CFrame.new(
		targetPosition.X,
		targetPosition.Y,
		targetPosition.Z,
		r00,
		r01,
		r02,
		r10,
		r11,
		r12,
		r20,
		r21,
		r22
	)
end

function RuntimeMapService.new()
	local self = setmetatable({}, RuntimeMapService)
	self._entityFactory = nil
	self._activeRuntimeModel = nil :: Model?
	return self
end

function RuntimeMapService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("MapEntityFactory")
end

function RuntimeMapService:CreateOrReplaceRuntimeMap(): Result.Result<boolean>
	local templateResult = self:_CloneTemplateModel(MapConfig.TEMPLATE_NAME)
	if not templateResult.success then
		return templateResult
	end

	local runtimeMapModel = templateResult.value
	local relocateResult = self:_RelocateRuntimeMap(runtimeMapModel)
	if not relocateResult.success then
		runtimeMapModel:Destroy()
		return relocateResult
	end

	local zonesResult = self:_DiscoverZones(runtimeMapModel)
	if not zonesResult.success then
		runtimeMapModel:Destroy()
		return zonesResult
	end

	self:CleanupRuntimeMap()

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

	local mapId = ("RuntimeMap_%d"):format(math.floor(os.clock() * 1000))
	self._entityFactory:CreateMapRoot(mapId, MapConfig.TEMPLATE_NAME, runtimeMapModel, zonesResult.value)

	return Ok(true)
end

function RuntimeMapService:CleanupRuntimeMap(): Result.Result<boolean>
	self._entityFactory:DeleteActiveMap()

	local model = self._activeRuntimeModel
	if model and model.Parent then
		model:Destroy()
	end

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

	self._activeRuntimeModel = nil
	return Ok(true)
end

function RuntimeMapService:_CloneTemplateModel(templateName: string): Result.Result<Model>
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	Ensure(assetsFolder, "MissingAssetsFolder", Errors.MISSING_ASSETS_FOLDER)

	local mapsFolder = assetsFolder:FindFirstChild("Maps")
	Ensure(mapsFolder, "MissingMapsFolder", Errors.MISSING_MAPS_FOLDER)

	local templateNode = mapsFolder:FindFirstChild(templateName) or mapsFolder:FindFirstChild("Default")
	if templateNode == nil then
		return Err("MapTemplateNotFound", Errors.MAP_TEMPLATE_NOT_FOUND, { Template = templateName })
	end

	local templateModel = _ExtractModel(templateNode)
	Ensure(templateModel, "MapTemplateInvalid", Errors.MAP_TEMPLATE_INVALID, { Template = templateNode.Name })

	return Ok(templateModel:Clone())
end

function RuntimeMapService:_DiscoverZones(runtimeMapModel: Model): Result.Result<ZoneMap>
	local zonesByName = {} :: ZoneMap

	for zoneName, zonePath in pairs(MapConfig.ZONE_PATHS) do
		local resolved = _ResolveZonePath(runtimeMapModel, zonePath)
		if resolved ~= nil then
			zonesByName[zoneName] = resolved
		end
	end

	for _, requiredZone in ipairs(MapConfig.REQUIRED_ZONES) do
		local zone = zonesByName[requiredZone]
		if zone == nil then
			return Err("RequiredZoneMissing", Errors.REQUIRED_ZONE_MISSING, { ZoneName = requiredZone })
		end
	end

	return Ok(zonesByName)
end

function RuntimeMapService:_RelocateRuntimeMap(runtimeMapModel: Model): Result.Result<boolean>
	local targetPositionResult = self:_ResolveRuntimeMapTargetPosition()
	if not targetPositionResult.success then
		return targetPositionResult
	end

	local targetPosition = targetPositionResult.value
	local pivotResult = fromPcall("RelocateRuntimeMapFailed", function()
		local currentPivot = runtimeMapModel:GetPivot()
		local targetPivot = _BuildCFrameWithPosition(currentPivot, targetPosition)
		runtimeMapModel:PivotTo(targetPivot)
	end)
	if not pivotResult.success then
		return Err("RelocateRuntimeMapFailed", Errors.FAILED_TO_RELOCATE_RUNTIME_MAP, {
			CauseMessage = pivotResult.message,
		})
	end

	return Ok(true)
end

function RuntimeMapService:_ResolveRuntimeMapTargetPosition(configuredPositionOverride: any?): Result.Result<Vector3>
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

function RuntimeMapService:GetActiveRuntimeModel(): Model?
	return self._activeRuntimeModel
end

return RuntimeMapService
