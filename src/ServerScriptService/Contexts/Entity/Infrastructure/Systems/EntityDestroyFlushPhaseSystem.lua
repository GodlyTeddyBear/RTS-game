--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityDestroyFlushPhaseSystem = {}
EntityDestroyFlushPhaseSystem.__index = EntityDestroyFlushPhaseSystem

function EntityDestroyFlushPhaseSystem.new(entityFactory: any)
	return setmetatable({
		_entityFactory = entityFactory,
	}, EntityDestroyFlushPhaseSystem)
end

function EntityDestroyFlushPhaseSystem:Run()
	local result = self._entityFactory:FlushDestroyQueue()
	if result.success then
		return
	end

	Result.MentionError("EntityDestroyFlushPhaseSystem:Run", "Entity deferred destruction flush failed", {
		CauseType = result.type,
		CauseMessage = result.message,
		Details = result.data,
	}, result.type)
end

return EntityDestroyFlushPhaseSystem
