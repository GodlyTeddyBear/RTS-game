--!strict

--[=[
	@class WaveCompletionPolicy
	Checks whether combat can advance because all enemies are gone.
	@server
]=]
local WaveCompletionPolicy = {}
WaveCompletionPolicy.__index = WaveCompletionPolicy

--[=[
	@within WaveCompletionPolicy
	Creates a new wave completion policy.
	@return WaveCompletionPolicy -- Policy instance used to gate wave completion.
]=]
function WaveCompletionPolicy.new()
	return setmetatable({}, WaveCompletionPolicy)
end

--[=[
	@within WaveCompletionPolicy
	Resolves the enemy entity factory used to inspect alive entities.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the policy.
]=]
function WaveCompletionPolicy:Init(_registry: any, _name: string)
end

--[=[
	@within WaveCompletionPolicy
	Stores the enemy entity factory needed by the policy.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the policy.
]=]
function WaveCompletionPolicy:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
end

--[=[
	@within WaveCompletionPolicy
	Returns whether the current combat wave has no alive enemies left.
	@return { Status: string } -- Completion status payload for the current wave.
]=]
function WaveCompletionPolicy:Check(): { Status: string }
	local aliveEntities = self._enemyEntityFactory:QueryAliveEntities()
	if #aliveEntities == 0 then
		return { Status = "WaveComplete" }
	end

	return { Status = "InProgress" }
end

return WaveCompletionPolicy
