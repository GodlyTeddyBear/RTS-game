--!strict

--[=[
	@class CombatLoopService
	Stub service for the future real-time combat phase. `StartCombatLoop` currently
	does nothing — combat must be ended manually via EndExpedition or FleeExpedition.
	@server
]=]
local CombatLoopService = {}
CombatLoopService.__index = CombatLoopService

export type TCombatLoopService = typeof(setmetatable({} :: { ActiveLoops: { [number]: { task: thread }? } }, CombatLoopService))

--[=[
	@within CombatLoopService
	@private
]=]
function CombatLoopService.new(): TCombatLoopService
	local self = setmetatable({}, CombatLoopService)
	-- { [userId]: { task: thread } } — populated when combat is implemented
	self.ActiveLoops = {} :: { [number]: { task: thread }? }
	return self
end

--[=[
	STUB: Does nothing. Future implementation will spawn entities and run combat ticks.
	@within CombatLoopService
	@param _userId number
	@param _player Player
	@param _onComplete (status: string) -> () -- Called with "Victory" or "Defeat"
]=]
function CombatLoopService:StartCombatLoop(_userId: number, _player: Player, _onComplete: (status: string) -> ())
	-- TODO: Implement real-time combat here in a future pass.
	-- For now, combat must be ended by calling EndExpedition manually (e.g. FleeExpedition or a test command).
end

--[=[
	Cancels the combat loop task for a player if one is running.
	@within CombatLoopService
	@param userId number
]=]
function CombatLoopService:StopCombatLoop(userId: number)
	local loop = self.ActiveLoops[userId]
	if loop and loop.task then
		task.cancel(loop.task)
	end
	self.ActiveLoops[userId] = nil
end

return CombatLoopService
