--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseInstanceFactory = require(ServerStorage.Utilities.ECSUtilities.BaseInstanceFactory)

local MiningInstanceFactory = {}
MiningInstanceFactory.__index = MiningInstanceFactory
setmetatable(MiningInstanceFactory, { __index = BaseInstanceFactory })

function MiningInstanceFactory.new()
	return setmetatable(BaseInstanceFactory.new("Mining"), MiningInstanceFactory)
end

function MiningInstanceFactory:_GetWorkspaceFolderName(): string
	return "MiningRuntime"
end

function MiningInstanceFactory:BindResourceNode(entity: number, instance: BasePart): BasePart
	assert(type(entity) == "number", "MiningInstanceFactory:BindResourceNode requires entity")
	assert(instance ~= nil, "MiningInstanceFactory:BindResourceNode requires instance")

	local currentInstance = self._entityToInstance[entity]
	if currentInstance ~= nil and currentInstance ~= instance then
		self:UnbindResourceNode(entity)
	end

	self._entityToInstance[entity] = instance
	self._instanceToEntity[instance] = entity
	return instance
end

function MiningInstanceFactory:UnbindResourceNode(entity: number): boolean
	local instance = self._entityToInstance[entity]
	if instance == nil then
		return false
	end

	self._entityToInstance[entity] = nil
	self._instanceToEntity[instance] = nil
	self._revealBindingsByEntity[entity] = nil
	return true
end

function MiningInstanceFactory:GetResourceNodeInstance(entity: number): BasePart?
	local instance = self:GetInstance(entity)
	return if instance ~= nil and instance:IsA("BasePart") then instance else nil
end

function MiningInstanceFactory:Destroy()
	local entityIds = {}
	for entity in self._entityToInstance do
		table.insert(entityIds, entity)
	end

	for _, entity in ipairs(entityIds) do
		self:UnbindResourceNode(entity)
	end
end

return MiningInstanceFactory
