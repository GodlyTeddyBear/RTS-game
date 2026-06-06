--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local EntityReplicationClient = require(script.Parent.Infrastructure.Persistence.EntityReplicationClient)
local ClientEntityIndexService = require(script.Parent.Infrastructure.Services.ClientEntityIndexService)
local ClientEntitySystemRegistry = require(script.Parent.Infrastructure.Services.ClientEntitySystemRegistry)

local EntityController = Knit.CreateController({
	Name = "EntityController",
})

function EntityController:KnitInit()
	self._replicationClient = EntityReplicationClient.new()
	self._entityIndexService = ClientEntityIndexService.new(self._replicationClient)
	self._systemRegistry = ClientEntitySystemRegistry.new()
	self._heartbeatConnection = nil
end

function EntityController:KnitStart()
	self._replicationClient:Init()
	self._replicationClient:Start()
	self._entityIndexService:Start()
	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		self._systemRegistry:Run()
	end)
end

function EntityController:GetByFeature(featureName: string)
	return self._entityIndexService:GetByFeature(featureName)
end

function EntityController:GetByArchetype(archetypeName: string)
	return self._entityIndexService:GetByArchetype(archetypeName)
end

function EntityController:GetByTag(tagName: string)
	return self._entityIndexService:GetByTag(tagName)
end

function EntityController:GetByIdentity(featureName: string, identityKey: string)
	return self._entityIndexService:GetByIdentity(featureName, identityKey)
end

function EntityController:ObserveByFeature(featureName: string, callback: (any) -> ())
	return self._entityIndexService:ObserveByFeature(featureName, callback)
end

function EntityController:ObserveByArchetype(archetypeName: string, callback: (any) -> ())
	return self._entityIndexService:ObserveByArchetype(archetypeName, callback)
end

function EntityController:GetEntity(entityId: number)
	return self._entityIndexService:GetEntity(entityId)
end

function EntityController:FindRecordByInstance(instance: Instance)
	return self._entityIndexService:FindRecordByInstance(instance)
end

function EntityController:FindInstanceByEntity(entityId: number)
	return self._entityIndexService:FindInstanceByEntity(entityId)
end

function EntityController:GetWorld()
	return self._replicationClient:GetWorldOrThrow()
end

function EntityController:GetComponents()
	return self._replicationClient:GetComponentsOrThrow()
end

function EntityController:ObserveStateChanged(callback: () -> ())
	return self._replicationClient:ObserveStateChanged(callback)
end

function EntityController:RegisterSystem(systemName: string, system: any)
	self._systemRegistry:Register(systemName, system)
end

function EntityController:Destroy()
	if self._heartbeatConnection ~= nil then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end
	if self._systemRegistry ~= nil then
		self._systemRegistry:Destroy()
		self._systemRegistry = nil
	end
	if self._entityIndexService ~= nil then
		self._entityIndexService:Destroy()
		self._entityIndexService = nil
	end

	if self._replicationClient ~= nil then
		self._replicationClient:Destroy()
		self._replicationClient = nil
	end
end

return EntityController
