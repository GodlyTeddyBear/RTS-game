--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type SlotKey = CommanderTypes.SlotKey
type CooldownEntry = CommanderTypes.CooldownEntry

--[=[
	@class CooldownService
	Calculates commander ability cooldown readiness from synced state.
	@server
]=]
local CooldownService = {}
CooldownService.__index = CooldownService

--[=[
	Creates a new commander cooldown service.
	@within CooldownService
	@return CooldownService -- The new service instance.
]=]
function CooldownService.new()
	return setmetatable({}, CooldownService)
end

--[=[
	Initializes the commander sync dependency.
	@within CooldownService
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function CooldownService:Init(registry: any, _name: string)
	self._syncService = registry:Get("CommanderSyncService")
end

-- Returns the remaining cooldown seconds for a slot entry; extracted so readiness logic stays readable.
local function getRemainingSeconds(cooldownEntry: CooldownEntry?): number
	if cooldownEntry == nil then
		return 0
	end

	local elapsed = os.clock() - cooldownEntry.startedAt
	return math.max(0, cooldownEntry.duration - elapsed)
end

--[=[
	Checks whether a commander ability slot is ready to use.
	@within CooldownService
	@param userId number -- The player user id.
	@param slotKey SlotKey -- The ability slot key to inspect.
	@return boolean -- `true` when the slot has no active cooldown.
]=]
function CooldownService:IsReady(userId: number, slotKey: SlotKey): boolean
	local state = self._syncService:GetStateReadOnly(userId)
	if state == nil then
		return false
	end

	return getRemainingSeconds(state.cooldowns[slotKey]) <= 0
end

--[=[
	Returns the remaining cooldown time for a commander ability slot.
	@within CooldownService
	@param userId number -- The player user id.
	@param slotKey SlotKey -- The ability slot key to inspect.
	@return number -- The remaining cooldown time in seconds.
]=]
function CooldownService:GetRemainingTime(userId: number, slotKey: SlotKey): number
	local state = self._syncService:GetStateReadOnly(userId)
	if state == nil then
		return 0
	end

	return getRemainingSeconds(state.cooldowns[slotKey])
end

return CooldownService
