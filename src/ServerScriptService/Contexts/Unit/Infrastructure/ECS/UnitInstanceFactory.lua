--!strict

--[=[
    @class UnitInstanceFactory
    Builds and prepares server-owned unit models for the unit ECS entity factory.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local BaseInstanceFactory = require(ServerStorage.Utilities.ECSUtilities.BaseInstanceFactory)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)

type UnitDefinition = UnitTypes.UnitDefinition
type UnitFaction = UnitTypes.UnitFaction
type UnitOwnerKind = UnitTypes.UnitOwnerKind

type TCreateUnitInstanceOptions = {
	UnitId: string,
	UnitGuid: string,
	Faction: UnitFaction,
	OwnerKind: UnitOwnerKind,
	OwnerId: string,
}

type ECSRevealOptions = {
	EntityType: string,
	SourceId: string,
	ScopeId: string,
	EntityId: string?,
	Namespace: string?,
}

local UnitInstanceFactory = {}
UnitInstanceFactory.__index = UnitInstanceFactory
setmetatable(UnitInstanceFactory, { __index = BaseInstanceFactory })

local UNIT_TAG = "CombatUnit"

-- Ensures the model carries a folder reference to the shared animations asset folder used by client animation setup.
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

-- Creates the instance factory with the unit namespace and no cached animation folder yet.
function UnitInstanceFactory.new()
	local self = setmetatable(BaseInstanceFactory.new("Unit"), UnitInstanceFactory)
	self._animationsFolder = nil :: Folder?
	return self
end

-- Reports the workspace folder name where live unit models should be parented.
function UnitInstanceFactory:_GetWorkspaceFolderName(): string
	return "Units"
end

-- Builds a unit asset registry from the shared `Assets/Units` folder when one exists.
function UnitInstanceFactory:_CreateAssetRegistry(assetsRoot: Folder): any
	local unitsFolder = assetsRoot:FindFirstChild("Units")
	if unitsFolder ~= nil and unitsFolder:IsA("Folder") then
		return AssetFetcher.CreateUnitRegistry(unitsFolder)
	end
	return nil
end

-- Caches the shared animations folder so newly created models can expose it to the client.
function UnitInstanceFactory:_OnInit(_registry: any, _name: string)
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	if assetsRoot == nil or not assetsRoot:IsA("Folder") then
		return
	end

	local animationsFolder = assetsRoot:FindFirstChild("Animations")
	if animationsFolder ~= nil and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end
end

-- Looks up the configured unit definition so fallback model creation stays consistent with gameplay data.
function UnitInstanceFactory:_GetDefinition(unitId: string): UnitDefinition
	local definition = UnitConfig.Definitions[unitId]
	assert(definition ~= nil, "Unknown unit id: " .. tostring(unitId))
	return definition
end

-- Creates a minimal fallback model when no asset-backed unit model is available.
function UnitInstanceFactory:_CreateFallbackModel(unitId: string, unitGuid: string): Model
	local definition = self:_GetDefinition(unitId)

	local model = Instance.new("Model")
	model.Name = "Unit_" .. unitId .. "_" .. unitGuid

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = definition.ModelScale
	rootPart.Color = definition.ModelColor
	rootPart.Material = Enum.Material.SmoothPlastic
	rootPart.Anchored = false
	rootPart.CanCollide = false
	rootPart.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = definition.MaxHp
	humanoid.Health = definition.MaxHp
	humanoid.WalkSpeed = definition.MoveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	return model
end

-- Returns either an asset-backed unit model or a fallback model for the requested unit definition.
function UnitInstanceFactory:_CreateInstanceForEntity(_entityId: number, options: TCreateUnitInstanceOptions): Instance
	local assetRegistry = self:_GetAssetRegistry()
	if assetRegistry ~= nil then
		local model = assetRegistry:GetUnitModel(options.UnitId)
		if model ~= nil then
			return model
		end
	end

	return self:_CreateFallbackModel(options.UnitId, options.UnitGuid)
end

-- Normalizes the model, animation metadata, and collision state before the model is revealed in the world.
function UnitInstanceFactory:_PrepareInstance(instance: Instance, _entityId: number, options: TCreateUnitInstanceOptions)
	assert(instance:IsA("Model"), "UnitInstanceFactory requires Model instances")

	local definition = self:_GetDefinition(options.UnitId)
	local model = instance :: Model
	model.Name = "Unit_" .. options.UnitId .. "_" .. options.UnitGuid
	_EnsureAnimationsFolderValue(model, self._animationsFolder)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end
	humanoid.MaxHealth = definition.MaxHp
	humanoid.Health = definition.MaxHp
	humanoid.WalkSpeed = definition.MoveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if model.PrimaryPart == nil then
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			model.PrimaryPart = rootPart
		end
	end

	assert(model.PrimaryPart ~= nil, "Unit model missing PrimaryPart: " .. model.Name)
	model.PrimaryPart.Anchored = false
	if model:GetAttribute("AnimationState") == nil then
		model:SetAttribute("AnimationState", "Idle")
	end
	if model:GetAttribute("AnimationLooping") == nil then
		model:SetAttribute("AnimationLooping", true)
	end
	EntityCollisionService:ApplyModel(model)
end

-- Builds the reveal payload so the server can expose the unit attributes and tags to clients.
function UnitInstanceFactory:_BuildRevealIdentityOptions(
	_entityId: number,
	_instance: Instance,
	options: TCreateUnitInstanceOptions
): ECSRevealOptions?
	return {
		EntityType = options.UnitId,
		SourceId = options.UnitGuid,
		ScopeId = options.OwnerKind .. ":" .. options.OwnerId,
		Namespace = "Unit",
	}
end

-- Exposes the spawn-time unit metadata as replicated attributes on the model.
function UnitInstanceFactory:_BuildRevealAttributes(
	_entityId: number,
	_instance: Instance,
	options: TCreateUnitInstanceOptions
): { [string]: any }?
	return {
		UnitId = options.UnitId,
		UnitGuid = options.UnitGuid,
		Faction = options.Faction,
		OwnerKind = options.OwnerKind,
		OwnerId = options.OwnerId,
	}
end

-- Tags every unit model so client contexts can discover it through collection-service tracking.
function UnitInstanceFactory:_BuildRevealTags(
	_entityId: number,
	_instance: Instance,
	_options: TCreateUnitInstanceOptions
): { [string]: boolean }?
	return {
		[UNIT_TAG] = true,
	}
end

-- Creates and returns the bound model for the requested unit entity.
function UnitInstanceFactory:CreateUnitInstance(
	entity: number,
	unitId: string,
	unitGuid: string,
	faction: UnitFaction,
	ownerKind: UnitOwnerKind,
	ownerId: string
): Model
	local instance = self:_CreateBoundInstance(entity, {
		UnitId = unitId,
		UnitGuid = unitGuid,
		Faction = faction,
		OwnerKind = ownerKind,
		OwnerId = ownerId,
	})

	assert(instance:IsA("Model"), "UnitInstanceFactory requires Model instances")
	return instance :: Model
end

return UnitInstanceFactory
