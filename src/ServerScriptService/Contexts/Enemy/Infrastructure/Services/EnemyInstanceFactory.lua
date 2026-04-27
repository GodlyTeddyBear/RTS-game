--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local BaseInstanceFactory = require(ReplicatedStorage.Utilities.BaseInstanceFactory)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)

type TCreateEnemyInstanceOptions = {
	role: string,
	enemyId: string,
	waveNumber: number,
}

type ECSRevealOptions = {
	EntityType: string,
	SourceId: string,
	ScopeId: string,
	EntityId: string?,
	Namespace: string?,
}

--[=[
	@class EnemyInstanceFactory
	Creates and manages enemy models in Workspace.Enemies.
	@server
]=]
local EnemyInstanceFactory = {}
EnemyInstanceFactory.__index = EnemyInstanceFactory
setmetatable(EnemyInstanceFactory, { __index = BaseInstanceFactory })

local ANIMATED_ENEMY_TAG = "AnimatedEnemy"

function EnemyInstanceFactory.new()
	local self = setmetatable(BaseInstanceFactory.new("Enemy"), EnemyInstanceFactory)
	self._animationsFolder = nil :: Folder?
	return self
end

function EnemyInstanceFactory:_GetWorkspaceFolderName(): string
	return "Enemies"
end

function EnemyInstanceFactory:_CreateAssetRegistry(assetsRoot: Folder): any
	local enemiesFolder = assetsRoot:FindFirstChild("Enemies")
	if enemiesFolder ~= nil and enemiesFolder:IsA("Folder") then
		return AssetFetcher.CreateEnemyRegistry(enemiesFolder)
	end

	return nil
end

function EnemyInstanceFactory:_OnInit(_registry: any, _name: string)
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	if assetsRoot == nil or not assetsRoot:IsA("Folder") then
		return
	end

	local animationsFolder = assetsRoot:FindFirstChild("Animations")
	if animationsFolder ~= nil and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end
end

function EnemyInstanceFactory:_CreateFallbackModel(role: string, enemyId: string): Model
	local roleConfig = EnemyConfig.ROLES[role]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(role))

	local model = Instance.new("Model")
	model.Name = "Enemy_" .. role .. "_" .. enemyId

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = roleConfig.modelScale
	rootPart.Color = roleConfig.modelColor
	rootPart.Material = Enum.Material.SmoothPlastic
	rootPart.Anchored = false
	rootPart.CanCollide = false
	rootPart.Massless = false
	rootPart.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = roleConfig.maxHp
	humanoid.Health = roleConfig.maxHp
	humanoid.WalkSpeed = roleConfig.moveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	return model
end

function EnemyInstanceFactory:_CreateInstanceForEntity(_entityId: number, options: TCreateEnemyInstanceOptions): Instance
	local role = options.role
	local enemyId = options.enemyId
	local assetRegistry = self:_GetAssetRegistry()

	if assetRegistry ~= nil and assetRegistry:EnemyModelExists(role) then
		local success, loadedModel = pcall(function()
			return assetRegistry:GetEnemyModel(role)
		end)
		if success and loadedModel ~= nil then
			return loadedModel
		end
	end

	return self:_CreateFallbackModel(role, enemyId)
end

function EnemyInstanceFactory:_PrepareInstance(instance: Instance, _entityId: number, options: TCreateEnemyInstanceOptions)
	assert(instance:IsA("Model"), "EnemyInstanceFactory requires Model instances")

	local roleConfig = EnemyConfig.ROLES[options.role]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(options.role))

	local model = instance :: Model
	model.Name = "Enemy_" .. options.role .. "_" .. options.enemyId

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

	if self._animationsFolder ~= nil then
		(animationsFolderRef :: ObjectValue).Value = self._animationsFolder
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end

	humanoid.MaxHealth = roleConfig.maxHp
	humanoid.Health = roleConfig.maxHp
	humanoid.WalkSpeed = roleConfig.moveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if model.PrimaryPart == nil then
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			model.PrimaryPart = rootPart
		end
	end

	assert(model.PrimaryPart ~= nil, "Enemy model missing PrimaryPart: " .. model.Name)
	model.PrimaryPart.Anchored = false
	EntityCollisionService:ApplyModel(model)
end

function EnemyInstanceFactory:_BuildRevealIdentityOptions(
	_entityId: number,
	_instance: Instance,
	options: TCreateEnemyInstanceOptions
): ECSRevealOptions?
	return {
		EntityType = options.role,
		SourceId = options.enemyId,
		ScopeId = tostring(options.waveNumber),
		Namespace = "Enemy",
	}
end

function EnemyInstanceFactory:_BuildRevealAttributes(
	_entityId: number,
	_instance: Instance,
	options: TCreateEnemyInstanceOptions
): { [string]: any }?
	return {
		EnemyId = options.enemyId,
		EnemyRole = options.role,
		WaveNumber = options.waveNumber,
	}
end

function EnemyInstanceFactory:_BuildRevealTags(
	_entityId: number,
	_instance: Instance,
	_options: TCreateEnemyInstanceOptions
): { [string]: boolean }?
	return {
		[ANIMATED_ENEMY_TAG] = true,
	}
end

function EnemyInstanceFactory:CreateEnemyInstance(entity: number, role: string, enemyId: string, waveNumber: number): Model
	local instance = self:_CreateBoundInstance(entity, {
		role = role,
		enemyId = enemyId,
		waveNumber = waveNumber,
	})

	assert(instance:IsA("Model"), "EnemyInstanceFactory requires Model instances")
	return instance :: Model
end

return EnemyInstanceFactory
