--!strict

--[=[
	@class WaveCompletionPolicy
	Checks whether combat can advance because all enemies are gone.
	@server
]=]
local WaveCompletionPolicy = {}
WaveCompletionPolicy.__index = WaveCompletionPolicy

-- Creates a new wave completion policy.
function WaveCompletionPolicy.new()
	return setmetatable({}, WaveCompletionPolicy)
end

-- Resolves the enemy entity factory used to inspect alive entities.
function WaveCompletionPolicy:Init(_registry: any, _name: string)
end

function WaveCompletionPolicy:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
end

-- Returns whether the current combat wave has no alive enemies left.
function WaveCompletionPolicy:Check(): { Status: string }
	local aliveEntities = self._enemyEntityFactory:QueryAliveEntities()
	if #aliveEntities == 0 then
		return { Status = "WaveComplete" }
	end

	return { Status = "InProgress" }
end

return WaveCompletionPolicy
