--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BaseInstanceFactory = require(ReplicatedStorage.Utilities.BaseInstanceFactory)
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

function UnitInstanceFactory.new()
	return setmetatable(BaseInstanceFactory.new("Unit"), UnitInstanceFactory)
end

function UnitInstanceFactory:_GetWorkspaceFolderName(): string
	return "Units"
end

function UnitInstanceFactory:_CreateAssetRegistry(assetsRoot: Folder): Folder?
	local unitsFolder = assetsRoot:FindFirstChild("Units")
	if unitsFolder ~= nil and unitsFolder:IsA("Folder") then
		return unitsFolder
	end
	return nil
end

function UnitInstanceFactory:_GetDefinition(unitId: string): UnitDefinition
	local definition = UnitConfig.Definitions[unitId]
	assert(definition ~= nil, "Unknown unit id: " .. tostring(unitId))
	return definition
end

function UnitInstanceFactory:_CreateFallbackModel(unitId: string, unitGuid: string): Model
	local definition = self:_GetDefinition(unitId)

	local model = Instance.new("Model")
	model.Name = "Unit_" .. unitId .. "_" .. unitGuid

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = definition.ModelScale
	rootPart.Color = definition.ModelColor
	rootPart.Material = Enum.Material.SmoothPlastic
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = definition.MaxHp
	humanoid.Health = definition.MaxHp
	humanoid.WalkSpeed = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	return model
end

function UnitInstanceFactory:_CreateInstanceForEntity(_entityId: number, options: TCreateUnitInstanceOptions): Instance
	local assetRegistry = self:_GetAssetRegistry()
	if assetRegistry ~= nil then
		local template = assetRegistry:FindFirstChild(options.UnitId)
		if template ~= nil and template:IsA("Model") then
			return template:Clone()
		end
	end

	return self:_CreateFallbackModel(options.UnitId, options.UnitGuid)
end

function UnitInstanceFactory:_PrepareInstance(instance: Instance, _entityId: number, options: TCreateUnitInstanceOptions)
	assert(instance:IsA("Model"), "UnitInstanceFactory requires Model instances")

	local definition = self:_GetDefinition(options.UnitId)
	local model = instance :: Model
	model.Name = "Unit_" .. options.UnitId .. "_" .. options.UnitGuid

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end
	humanoid.MaxHealth = definition.MaxHp
	humanoid.Health = definition.MaxHp
	humanoid.WalkSpeed = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if model.PrimaryPart == nil then
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			model.PrimaryPart = rootPart
		end
	end

	assert(model.PrimaryPart ~= nil, "Unit model missing PrimaryPart: " .. model.Name)
	model.PrimaryPart.Anchored = true
	EntityCollisionService:ApplyModel(model)
end

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

function UnitInstanceFactory:_BuildRevealTags(
	_entityId: number,
	_instance: Instance,
	_options: TCreateUnitInstanceOptions
): { [string]: boolean }?
	return {
		[UNIT_TAG] = true,
	}
end

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
