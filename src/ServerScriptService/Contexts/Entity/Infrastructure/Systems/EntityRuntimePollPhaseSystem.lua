--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityRuntimePollPhaseSystem = {}
EntityRuntimePollPhaseSystem.__index = EntityRuntimePollPhaseSystem

function EntityRuntimePollPhaseSystem.new(entityContext: any, runtimeSyncService: any)
	return setmetatable({
		_entityContext = entityContext,
		_runtimeSyncService = runtimeSyncService,
	}, EntityRuntimePollPhaseSystem)
end

function EntityRuntimePollPhaseSystem:Run()
	local result = self._runtimeSyncService:RunRuntimePoll(self._entityContext)
	if result.success then
		return
	end

	Result.MentionError("EntityRuntimePollPhaseSystem:Run", "Entity runtime poll failed", {
		CauseType = result.type,
		CauseMessage = result.message,
		Details = result.data,
	}, result.type)
end

return EntityRuntimePollPhaseSystem
