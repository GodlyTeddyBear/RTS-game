--!strict

--[=[
	@class RemoteLotTracker
	Tracks active remote lots and their grid slot allocations.
	@server
]=]

--[[
	Tracks which players have active remote lots and which slot index
	they occupy in the remote terrain grid.

	Slot indices are allocated on spawn and freed on cleanup.
	This keeps remote lot positions stable and non-overlapping.
]]

local RemoteLotTracker = {}
RemoteLotTracker.__index = RemoteLotTracker

export type TRemoteLotTracker = typeof(setmetatable(
	{} :: {
		_playerToSlot: { [Player]: number },
		_usedSlots: { [number]: boolean },
		_playerToModel: { [Player]: Model },
		_playerToSpawnCFrame: { [Player]: CFrame },
	},
	RemoteLotTracker
))

function RemoteLotTracker.new(): TRemoteLotTracker
	local self = setmetatable({}, RemoteLotTracker)
	self._playerToSlot = {}
	self._usedSlots = {}
	self._playerToModel = {}
	self._playerToSpawnCFrame = {}
	return self
end

function RemoteLotTracker:Init(_registry: any, _name: string) end

--[=[
	Allocates the next available slot index for a player.
	Slots start at 0 and increment.
	@within RemoteLotTracker
	@param player Player
	@return number -- The allocated slot index
]=]
function RemoteLotTracker:AllocateSlot(player: Player): number
	-- Find the first unused slot
	local slot = 0
	while self._usedSlots[slot] do
		slot += 1
	end
	-- Mark slot as in use and track player → slot mapping
	self._usedSlots[slot] = true
	self._playerToSlot[player] = slot
	return slot
end

--[=[
	Returns the slot index held by a player, or nil.
	@within RemoteLotTracker
	@param player Player
	@return number? -- The slot index, or nil if player has no slot
]=]
function RemoteLotTracker:GetSlot(player: Player): number?
	return self._playerToSlot[player]
end

--[=[
	Frees the slot held by a player.
	@within RemoteLotTracker
	@param player Player
]=]
function RemoteLotTracker:FreeSlot(player: Player)
	local slot = self._playerToSlot[player]
	if slot ~= nil then
		-- Clear both slot usage and player mapping
		self._usedSlots[slot] = nil
		self._playerToSlot[player] = nil
	end
end

--[=[
	Stores the remote lot model for a player.
	@within RemoteLotTracker
	@param player Player
	@param model Model
]=]
function RemoteLotTracker:SetModel(player: Player, model: Model)
	self._playerToModel[player] = model
end

--[=[
	Returns the remote lot model for a player, or nil.
	@within RemoteLotTracker
	@param player Player
	@return Model? -- The remote lot model, or nil if not found
]=]
function RemoteLotTracker:GetModel(player: Player): Model?
	return self._playerToModel[player]
end

--[=[
	Removes the model reference for a player.
	@within RemoteLotTracker
	@param player Player
]=]
function RemoteLotTracker:ClearModel(player: Player)
	self._playerToModel[player] = nil
end

--[=[
	Stores the spawn CFrame for a player's remote lot.
	@within RemoteLotTracker
	@param player Player
	@param cframe CFrame
]=]
function RemoteLotTracker:SetSpawnCFrame(player: Player, cframe: CFrame)
	self._playerToSpawnCFrame[player] = cframe
end

--[=[
	Returns the spawn CFrame for a player's remote lot, or nil.
	@within RemoteLotTracker
	@param player Player
	@return CFrame? -- The spawn CFrame, or nil if not found
]=]
function RemoteLotTracker:GetSpawnCFrame(player: Player): CFrame?
	return self._playerToSpawnCFrame[player]
end

--[=[
	Removes the spawn CFrame for a player.
	@within RemoteLotTracker
	@param player Player
]=]
function RemoteLotTracker:ClearSpawnCFrame(player: Player)
	self._playerToSpawnCFrame[player] = nil
end

--[=[
	Returns true if the player has an active remote lot.
	@within RemoteLotTracker
	@param player Player
	@return boolean
]=]
function RemoteLotTracker:Has(player: Player): boolean
	return self._playerToSlot[player] ~= nil
end

return RemoteLotTracker
