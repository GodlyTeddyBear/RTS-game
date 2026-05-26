--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local EntityReplicationClient = require(script.Parent.Infrastructure.Persistence.EntityReplicationClient)
local ClientEntityIndexService = require(script.Parent.Infrastructure.Services.ClientEntityIndexService)

local EntityController = Knit.CreateController({
	Name = "EntityController",
})

function EntityController:KnitInit()
	self._replicationClient = EntityReplicationClient.new()
	self._entityIndexService = ClientEntityIndexService.new(self._replicationClient)
end

function EntityController:KnitStart()
	self._replicationClient:Init()
	self._replicationClient:Start()
	self._entityIndexService:Start()
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

function EntityController:Destroy()
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
