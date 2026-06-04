--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityRuntimeSyncPhaseSystem = {}
EntityRuntimeSyncPhaseSystem.__index = EntityRuntimeSyncPhaseSystem

function EntityRuntimeSyncPhaseSystem.new(entityContext: any, runtimeSyncService: any)
	return setmetatable({
		_entityContext = entityContext,
		_runtimeSyncService = runtimeSyncService,
	}, EntityRuntimeSyncPhaseSystem)
end

function EntityRuntimeSyncPhaseSystem:Run()
	local result = self._runtimeSyncService:RunRuntimeSync(self._entityContext)
	if result.success then
		return
	end

	Result.MentionError("EntityRuntimeSyncPhaseSystem:Run", "Entity runtime sync failed", {
		CauseType = result.type,
		CauseMessage = result.message,
		Details = result.data,
	}, result.type)
end

return EntityRuntimeSyncPhaseSystem
