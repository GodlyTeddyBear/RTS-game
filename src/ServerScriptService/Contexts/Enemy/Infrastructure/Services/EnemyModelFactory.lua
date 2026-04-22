--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

--[=[
	@class EnemyModelFactory
	Creates and manages enemy models in Workspace.Enemies.
	@server
]=]
local EnemyModelFactory = {}
EnemyModelFactory.__index = EnemyModelFactory

local ANIMATED_ENEMY_TAG = "AnimatedEnemy"

function EnemyModelFactory.new()
	local self = setmetatable({}, EnemyModelFactory)
	self._entityRegistry = nil
	self._folder = nil :: Folder?
	self._animationsFolder = nil :: Folder?
	return self
end

local function _findOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function EnemyModelFactory:Init(_registry: any, _name: string)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local enemiesFolder = assets and assets:FindFirstChild("Enemies")
	if enemiesFolder and enemiesFolder:IsA("Folder") then
		self._entityRegistry = AssetFetcher.CreateEnemyRegistry(enemiesFolder)
	end
	local animationsFolder = assets and assets:FindFirstChild("Animations")
	if animationsFolder and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end

	self._folder = _findOrCreateFolder(Workspace, "Enemies")
end

function EnemyModelFactory:_CreateFallbackModel(role: string, enemyId: string): Model
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

function EnemyModelFactory:_PrepareModel(model: Model, role: string, enemyId: string, waveNumber: number)
	local roleConfig = EnemyConfig.ROLES[role]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(role))

	if model.Parent ~= self._folder then
		model.Parent = self._folder
	end

	model.Name = "Enemy_" .. role .. "_" .. enemyId
	model:SetAttribute("EnemyId", enemyId)
	model:SetAttribute("EnemyRole", role)
	model:SetAttribute("WaveNumber", waveNumber)
	model:SetAttribute("Health", roleConfig.maxHp)
	model:SetAttribute("MaxHealth", roleConfig.maxHp)
	model:SetAttribute("MoveSpeed", roleConfig.moveSpeed)
	model:SetAttribute("Damage", roleConfig.damage)
	model:SetAttribute("TargetPreference", roleConfig.targetPreference)
	model:SetAttribute("Alive", true)
	model:SetAttribute("GoalReached", false)
	model:SetAttribute("AnimationState", "Idle")
	model:SetAttribute("AnimationLooping", true)

	if not CollectionService:HasTag(model, ANIMATED_ENEMY_TAG) then
		CollectionService:AddTag(model, ANIMATED_ENEMY_TAG)
	end

	local animationsFolderRef = model:FindFirstChild("AnimationsFolder")
	if not animationsFolderRef or not animationsFolderRef:IsA("ObjectValue") then
		if animationsFolderRef then
			animationsFolderRef:Destroy()
		end
		animationsFolderRef = Instance.new("ObjectValue")
		animationsFolderRef.Name = "AnimationsFolder"
		animationsFolderRef.Parent = model
	end

	if self._animationsFolder and (animationsFolderRef :: ObjectValue).Value == nil then
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
		if rootPart and rootPart:IsA("BasePart") then
			model.PrimaryPart = rootPart
		end
	end

	assert(model.PrimaryPart ~= nil, "Enemy model missing PrimaryPart: " .. model.Name)
end

function EnemyModelFactory:CreateEnemyModel(role: string, enemyId: string, waveNumber: number): Model
	local model: Model? = nil

	if self._entityRegistry and self._entityRegistry:EnemyModelExists(role) then
		local success, loadedModel = pcall(function()
			return self._entityRegistry:GetEnemyModel(role)
		end)
		if success and loadedModel then
			model = loadedModel
		end
	end

	if model == nil then
		model = self:_CreateFallbackModel(role, enemyId)
	end

	self:_PrepareModel(model, role, enemyId, waveNumber)
	return model
end

function EnemyModelFactory:DestroyModel(model: Model)
	if CollectionService:HasTag(model, ANIMATED_ENEMY_TAG) then
		CollectionService:RemoveTag(model, ANIMATED_ENEMY_TAG)
	end
	model:Destroy()
end

function EnemyModelFactory:DestroyAllModels()
	if self._folder then
		self._folder:ClearAllChildren()
	end
end

return EnemyModelFactory
