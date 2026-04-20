--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)

--[=[
	@class MachineRuntimeStore
	Persists per-slot machine runtime state under profile production data.
	@server
]=]

--[=[
	@interface TMachineJob
	@within MachineRuntimeStore
	.recipeId string -- Recipe identifier queued for processing.
	.progressSeconds number -- Current elapsed processing time.
]=]
export type TMachineJob = {
	recipeId: string,
	progressSeconds: number,
}

--[=[
	@interface TMachineSlotState
	@within MachineRuntimeStore
	.fuelSecondsRemaining number -- Remaining seconds of burn time.
	.queue { TMachineJob } -- Ordered job queue for the machine.
	.outputItemId string? -- Pending output item identifier.
	.outputQuantity number? -- Pending output quantity.
]=]
export type TMachineSlotState = {
	fuelSecondsRemaining: number,
	queue: { TMachineJob },
	outputItemId: string?,
	outputQuantity: number?,
}

local MachineRuntimeStore = {}
MachineRuntimeStore.__index = MachineRuntimeStore

export type TMachineRuntimeStore = typeof(setmetatable({}, MachineRuntimeStore))

local MAX_QUEUE = 8

--[=[
	Create a machine runtime store.
	@within MachineRuntimeStore
	@return TMachineRuntimeStore -- New runtime store instance.
]=]
function MachineRuntimeStore.new(): TMachineRuntimeStore
	return setmetatable({}, MachineRuntimeStore)
end

--[=[
	Build the machine runtime dictionary key for a slot.
	@within MachineRuntimeStore
	@param zoneName string -- Zone name for the machine.
	@param slotIndex number -- One-based slot index.
	@return string -- Composite runtime key in `Zone:Slot` format.
]=]
function MachineRuntimeStore.SlotKey(zoneName: string, slotIndex: number): string
	return zoneName .. ":" .. tostring(slotIndex)
end

--[=[
	Parse a runtime slot key into zone and slot components.
	@within MachineRuntimeStore
	@param key string -- Composite runtime key in `Zone:Slot` format.
	@return string? -- Parsed zone name when valid.
	@return number? -- Parsed slot index when valid.
]=]
function MachineRuntimeStore.ParseSlotKey(key: string): (string?, number?)
	local colon = string.find(key, ":", 1, true)
	if not colon or colon < 2 then
		return nil, nil
	end
	local zone = string.sub(key, 1, colon - 1)
	local n = tonumber(string.sub(key, colon + 1))
	return zone, n
end

-- Ensure profile production runtime root exists before reads/writes.
function MachineRuntimeStore:_ensureRoot(data: any)
	if not data.Production.MachineRuntime then
		data.Production.MachineRuntime = {}
	end
	return data.Production.MachineRuntime
end

-- Build a fresh empty slot state when a machine key is first touched.
function MachineRuntimeStore:_defaultState(): TMachineSlotState
	return {
		fuelSecondsRemaining = 0,
		queue = {},
		outputItemId = nil,
		outputQuantity = nil,
	}
end

--[=[
	Get or create runtime state for a machine slot.
	@within MachineRuntimeStore
	@param player Player -- Player owning the machine runtime.
	@param zoneName string -- Zone name for the machine.
	@param slotIndex number -- One-based slot index.
	@return TMachineSlotState? -- Mutable runtime state, or `nil` when profile is missing.
]=]
function MachineRuntimeStore:GetState(player: Player, zoneName: string, slotIndex: number): TMachineSlotState?
	local data = ProfileManager:GetData(player)
	if not data then
		return nil
	end
	local root = self:_ensureRoot(data)
	local key = MachineRuntimeStore.SlotKey(zoneName, slotIndex)
	local st = root[key]
	if not st then
		st = self:_defaultState()
		root[key] = st
	end
	if type(st.queue) ~= "table" then
		st.queue = {}
	end
	if type(st.fuelSecondsRemaining) ~= "number" then
		st.fuelSecondsRemaining = 0
	end
	return st
end

--[=[
	Get all machine runtime entries for a player.
	@within MachineRuntimeStore
	@param player Player -- Player owning runtime state.
	@return { [string]: TMachineSlotState } -- Map of slot key to runtime state.
]=]
function MachineRuntimeStore:GetAllForPlayer(player: Player): { [string]: TMachineSlotState }
	local data = ProfileManager:GetData(player)
	if not data then
		return {}
	end
	return self:_ensureRoot(data)
end

--[=[
	Clear all machine runtime state for a player.
	@within MachineRuntimeStore
	@param player Player -- Player whose runtime state should be cleared.
]=]
function MachineRuntimeStore:ClearAllForPlayer(player: Player)
	local data = ProfileManager:GetData(player)
	if not data then
		return
	end
	data.Production.MachineRuntime = {}
end

--[=[
	Get maximum allowed machine queue size.
	@within MachineRuntimeStore
	@return number -- Maximum job count per machine queue.
]=]
function MachineRuntimeStore.MaxQueueSize(): number
	return MAX_QUEUE
end

return MachineRuntimeStore
