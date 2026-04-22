--!strict

--[[
	EnemyRegistry - Load Enemy Models with Default Fallback

	Provides a registry for loading enemy models from Assets/Enemies with
	automatic fallback to Default when a role-specific model is missing.
]]

local EnemyRegistry = {}
EnemyRegistry.__index = EnemyRegistry

function EnemyRegistry.new(enemiesFolder: Folder)
	assert(enemiesFolder, "EnemyRegistry requires a valid Enemies folder")
	assert(enemiesFolder:IsA("Folder"), "EnemyRegistry requires a Folder instance")

	local self = setmetatable({}, EnemyRegistry)
	self._enemiesFolder = enemiesFolder

	return self
end

function EnemyRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end

	return nil
end

function EnemyRegistry:_ResolveTemplate(enemyName: string): Model?
	local typeNode = self._enemiesFolder:FindFirstChild(enemyName)
	local typeModel = typeNode and self:_ExtractModel(typeNode)
	if typeModel ~= nil then
		return typeModel
	end

	local defaultNode = self._enemiesFolder:FindFirstChild("Default")
	local defaultModel = defaultNode and self:_ExtractModel(defaultNode)
	return defaultModel
end

function EnemyRegistry:GetEnemyModel(enemyName: string): Model?
	local template = self:_ResolveTemplate(enemyName)
	if template == nil then
		return nil
	end

	return template:Clone()
end

function EnemyRegistry:EnemyModelExists(enemyName: string): boolean
	return self:_ResolveTemplate(enemyName) ~= nil
end

return EnemyRegistry
