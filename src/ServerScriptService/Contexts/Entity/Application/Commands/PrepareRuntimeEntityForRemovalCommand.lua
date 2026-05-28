--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local PrepareRuntimeEntityForRemovalCommand = {}
PrepareRuntimeEntityForRemovalCommand.__index = PrepareRuntimeEntityForRemovalCommand
setmetatable(PrepareRuntimeEntityForRemovalCommand, BaseCommand)

function PrepareRuntimeEntityForRemovalCommand.new()
	local self = BaseCommand.new("Entity", "PrepareRuntimeEntityForRemoval")
	return setmetatable(self, PrepareRuntimeEntityForRemovalCommand)
end

function PrepareRuntimeEntityForRemovalCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_runtimeParticipationPolicy = "EntityRuntimeParticipationPolicy",
		_replicationService = "EntityReplicationService",
		_entityContext = "EntityContextService",
		_preDestroyCleanupRegistry = "EntityPreDestroyCleanupRegistry",
	})
end

function PrepareRuntimeEntityForRemovalCommand:Execute(
	entity: number,
	unregisterRuntimeEntity: boolean
): Result.Result<boolean>
	return Result.Catch(function()
		local cleanupResult = self._preDestroyCleanupRegistry:Run(entity)
		if not cleanupResult.success then
			return cleanupResult
		end

		self._instanceBindingService:ClearQueuedBind(entity)

		if self._runtimeParticipationPolicy:ShouldRegisterReplication(self._runtimeParticipation, entity) then
			local unregisterReplicationResult = self._replicationService:UnregisterRuntimeEntity(self._entityContext, entity)
			if not unregisterReplicationResult.success then
				return unregisterReplicationResult
			end
		end

		local unbindResult = self._instanceBindingService:UnbindEntityInstance(entity)
		if not unbindResult.success then
			return unbindResult
		end

		if unregisterRuntimeEntity then
			local unregisterRuntimeResult = self._runtimeParticipation:UnregisterRuntimeEntity(entity)
			if not unregisterRuntimeResult.success then
				return unregisterRuntimeResult
			end
		end

		return Result.Ok(true)
	end, self:_Label())
end

return PrepareRuntimeEntityForRemovalCommand
