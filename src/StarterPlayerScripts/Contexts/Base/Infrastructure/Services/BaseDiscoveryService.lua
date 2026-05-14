--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Contexts.Base.Config.BaseConfig)
local ECS = require(ReplicatedStorage.Utilities.ECS)

local BaseDiscoveryService = {}
BaseDiscoveryService.__index = BaseDiscoveryService

function BaseDiscoveryService.new()
	local self = setmetatable({}, BaseDiscoveryService)
	self._index = ECS.DiscoveryIndexService.new({
		Namespace = BaseConfig.REVEAL_NAMESPACE,
		PollIntervalSeconds = 0.25,
	})
	self._baseEntityId = ECS.IdentitySchema.MakeScopedEntityId(
		BaseConfig.REVEAL_SCOPE_ID,
		BaseConfig.REVEAL_ENTITY_TYPE,
		BaseConfig.BASE_ID
	)
	return self
end

function BaseDiscoveryService:Start()
	self._index:Start()
end

function BaseDiscoveryService:GetActiveBaseInstance(): Instance?
	return self._index:FindFirstByTypeAndId(BaseConfig.REVEAL_ENTITY_TYPE, self._baseEntityId)
end

function BaseDiscoveryService:Destroy()
	self._index:Destroy()
end

return BaseDiscoveryService
