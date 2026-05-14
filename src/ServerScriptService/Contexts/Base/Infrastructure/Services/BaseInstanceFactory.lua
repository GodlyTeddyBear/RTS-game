--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseConfig = require(ReplicatedStorage.Contexts.Base.Config.BaseConfig)
local BaseInstanceFactoryBase = require(ReplicatedStorage.Utilities.BaseInstanceFactory)

type TBindBaseInstanceOptions = {
	BaseId: string,
	Anchor: BasePart,
}

type ECSRevealOptions = {
	EntityType: string,
	SourceId: string,
	ScopeId: string,
	EntityId: string?,
	Namespace: string?,
}

local BaseInstanceFactory = {}
BaseInstanceFactory.__index = BaseInstanceFactory
setmetatable(BaseInstanceFactory, { __index = BaseInstanceFactoryBase })

function BaseInstanceFactory.new()
	return setmetatable(BaseInstanceFactoryBase.new("Base"), BaseInstanceFactory)
end

function BaseInstanceFactory:Init(_registry: any, _name: string)
	assert(RunService:IsServer(), "BaseInstanceFactory is server-only")
end

function BaseInstanceFactory:_BuildRevealIdentityOptions(
	_entityId: number,
	_instance: Instance,
	options: TBindBaseInstanceOptions
): ECSRevealOptions?
	return {
		EntityType = BaseConfig.REVEAL_ENTITY_TYPE,
		SourceId = options.BaseId,
		ScopeId = BaseConfig.REVEAL_SCOPE_ID,
		Namespace = BaseConfig.REVEAL_NAMESPACE,
	}
end

function BaseInstanceFactory:_BuildRevealAttributes(
	_entityId: number,
	_instance: Instance,
	options: TBindBaseInstanceOptions
): { [string]: any }?
	return {
		BaseId = options.BaseId,
	}
end

function BaseInstanceFactory:_BuildRevealClearAttributes(
	_entityId: number,
	_instance: Instance,
	_options: TBindBaseInstanceOptions
): { string }?
	return { "BaseId" }
end

function BaseInstanceFactory:BindBaseInstance(
	entity: number,
	instance: Instance,
	anchor: BasePart,
	baseId: string
): Instance
	assert(type(entity) == "number", "BaseInstanceFactory:BindBaseInstance requires entity")
	assert(instance ~= nil, "BaseInstanceFactory:BindBaseInstance requires instance")
	assert(anchor ~= nil, "BaseInstanceFactory:BindBaseInstance requires anchor")
	assert(type(baseId) == "string" and baseId ~= "", "BaseInstanceFactory:BindBaseInstance requires baseId")

	local currentInstance = self._entityToInstance[entity]
	local options: TBindBaseInstanceOptions = {
		BaseId = baseId,
		Anchor = anchor,
	}

	if currentInstance ~= nil and currentInstance ~= instance then
		self:UnbindBaseInstance(entity)
	end

	self._entityToInstance[entity] = instance
	self._instanceToEntity[instance] = entity

	if self._revealBindingsByEntity[entity] ~= nil then
		self:RefreshReveal(entity, options)
	else
		self:RegisterReveal(entity, instance, options)
	end

	return instance
end

function BaseInstanceFactory:UnbindBaseInstance(entity: number): boolean
	local instance = self._entityToInstance[entity]
	if instance == nil then
		return false
	end

	local clearState = self:_BuildClearRevealState(instance, entity)
	if clearState ~= nil and instance.Parent ~= nil then
		self:ClearReveal(instance, clearState)
	end

	self._entityToInstance[entity] = nil
	self._instanceToEntity[instance] = nil
	self._revealBindingsByEntity[entity] = nil
	return true
end

function BaseInstanceFactory:GetBaseInstance(entity: number): Instance?
	return self._entityToInstance[entity]
end

function BaseInstanceFactory:GetBaseModel(entity: number): Model?
	local instance = self:GetBaseInstance(entity)
	if instance == nil then
		return nil
	end

	if instance:IsA("Model") then
		return instance
	end

	return instance:FindFirstAncestorOfClass("Model")
end

function BaseInstanceFactory:Destroy()
	local entityIds = {}
	for entity in self._entityToInstance do
		table.insert(entityIds, entity)
	end

	for _, entity in ipairs(entityIds) do
		self:UnbindBaseInstance(entity)
	end
end

return BaseInstanceFactory
