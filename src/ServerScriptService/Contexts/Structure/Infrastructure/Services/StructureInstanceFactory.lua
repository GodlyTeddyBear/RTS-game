--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local BaseInstanceFactory = require(ReplicatedStorage.Utilities.BaseInstanceFactory)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)

type TCreateStructureInstanceOptions = {
	structureType: string,
	instanceId: number,
	worldPos: Vector3,
}

local StructureInstanceFactory = {}
StructureInstanceFactory.__index = StructureInstanceFactory
setmetatable(StructureInstanceFactory, { __index = BaseInstanceFactory })

local function _BuildBottomAlignedPivot(model: Model, targetWorldPos: Vector3): CFrame
	local currentPivot = model:GetPivot()
	local boundsCFrame, boundsSize = model:GetBoundingBox()

	local currentBottomY = boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
	local yOffset = targetWorldPos.Y - currentBottomY
	local targetPivotPosition = Vector3.new(targetWorldPos.X, currentPivot.Position.Y + yOffset, targetWorldPos.Z)

	local pivotRotation = currentPivot - currentPivot.Position
	return CFrame.new(targetPivotPosition) * pivotRotation
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

function StructureInstanceFactory.new()
	local self = setmetatable(BaseInstanceFactory.new("Structure"), StructureInstanceFactory)
	self._animationsFolder = nil :: Folder?
	return self
end

function StructureInstanceFactory:_GetWorkspaceFolderName(): string
	return PlacementConfig.PLACEMENT_FOLDER_NAME
end

function StructureInstanceFactory:_CreateAssetRegistry(assetsRoot: Folder): any
	local structuresFolder = assetsRoot:FindFirstChild("Structures")
	if structuresFolder ~= nil and structuresFolder:IsA("Folder") then
		return AssetFetcher.CreateStructureRegistry(structuresFolder)
	end

	return nil
end

function StructureInstanceFactory:_OnInit(_registry: any, _name: string)
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	if assetsRoot == nil or not assetsRoot:IsA("Folder") then
		return
	end

	local animationsFolder = assetsRoot:FindFirstChild("Animations")
	if animationsFolder ~= nil and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end
end

function StructureInstanceFactory:_CreateInstanceForEntity(_entityId: number, options: TCreateStructureInstanceOptions): Instance
	local assetRegistry = self:_GetAssetRegistry()
	assert(assetRegistry ~= nil, "StructureInstanceFactory: missing structure asset registry")

	local model = assetRegistry:GetStructureModel(options.structureType)
	assert(model ~= nil, "StructureInstanceFactory: missing structure model for " .. tostring(options.structureType))
	return model
end

function StructureInstanceFactory:_PrepareInstance(instance: Instance, _entityId: number, options: TCreateStructureInstanceOptions)
	assert(instance:IsA("Model"), "StructureInstanceFactory requires Model instances")

	local model = instance :: Model
	model.Name = options.structureType .. "_" .. tostring(options.instanceId)
	model:SetAttribute("PlacementInstanceId", options.instanceId)

	_PrepareStructureAnimationRuntime(model, self._animationsFolder)
	model:PivotTo(_BuildBottomAlignedPivot(model, options.worldPos))
	EntityCollisionService:ApplyStructureModel(model)
end

function StructureInstanceFactory:CreateStructureInstance(
	entity: number,
	structureType: string,
	instanceId: number,
	worldPos: Vector3
): Model
	local instance = self:_CreateBoundInstance(entity, {
		structureType = structureType,
		instanceId = instanceId,
		worldPos = worldPos,
	})

	assert(instance:IsA("Model"), "StructureInstanceFactory requires Model instances")
	return instance :: Model
end

return StructureInstanceFactory
