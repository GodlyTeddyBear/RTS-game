--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

--[=[
	@class EndCombat
	Cancels active executors and clears active combat sessions.
	@server
]=]
local EndCombat = {}
EndCombat.__index = EndCombat

--[=[
	@within EndCombat
	Creates a new combat teardown command.
	@return EndCombat -- Command instance used to end combat sessions.
]=]
function EndCombat.new()
	return setmetatable({}, EndCombat)
end

--[=[
	@within EndCombat
	Resolves the combat loop, executor registry, and enemy factory dependencies.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function EndCombat:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
	self._executorRegistry = registry:Get("ExecutorRegistry")
end

--[=[
	@within EndCombat
	Stores the enemy factory needed to clear combat-owned state.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the command.
]=]
function EndCombat:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
end

--[=[
	@within EndCombat
	Cancels every active executor, clears enemy action state, and stops the active combat session.
	@param userId number? -- Optional user id to stop; falls back to the first connected player.
	@return Result.Result<boolean> -- Success confirmation or a typed combat error.
]=]
function EndCombat:Execute(userId: number?): Result.Result<boolean>
	return Result.Catch(function()
		-- Default to the lone player when callers omit an explicit user id.
		local targetUserId = userId
		if targetUserId == nil then
			local players = Players:GetPlayers()
			if players[1] then
				targetUserId = players[1].UserId
			end
		end

		-- Build the cleanup payload once so each executor gets the same service view.
		local services = {
			EnemyEntityFactory = self._enemyEntityFactory,
			CurrentTime = os.clock(),
		}

		-- Cancel each alive enemy's registered executor before clearing its action state.
		for _, entity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
			self._executorRegistry:CancelAll(entity, services)
			self._enemyEntityFactory:ClearAction(entity)
		end

		if targetUserId then
			self._loopService:StopCombat(targetUserId)
		end

		return Ok(true)
	end, "Combat:EndCombat")
end

return EndCombat
