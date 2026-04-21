--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type SlotKey = CommanderTypes.SlotKey

--[=[
	@class GetCooldownQuery
	Reads commander cooldown timing through the sync service.
	@server
]=]
local GetCooldownQuery = {}
GetCooldownQuery.__index = GetCooldownQuery

--[=[
	Creates a new cooldown query.
	@within GetCooldownQuery
	@return GetCooldownQuery -- The new query instance.
]=]
function GetCooldownQuery.new()
	return setmetatable({}, GetCooldownQuery)
end

--[=[
	Initializes the cooldown-service dependency.
	@within GetCooldownQuery
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function GetCooldownQuery:Init(registry: any, _name: string)
	self._cooldownService = registry:Get("CooldownService")
end

--[=[
	Returns the remaining cooldown time for a commander slot.
	@within GetCooldownQuery
	@param userId number -- The player user id.
	@param slotKey SlotKey -- The ability slot key to inspect.
	@return number -- The remaining cooldown time in seconds.
]=]
function GetCooldownQuery:Execute(userId: number, slotKey: SlotKey): number
	return self._cooldownService:GetRemainingTime(userId, slotKey)
end

return GetCooldownQuery
