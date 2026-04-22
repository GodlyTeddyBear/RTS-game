--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local CommanderConfig = require(ReplicatedStorage.Contexts.Commander.Config.CommanderConfig)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)
local AbilitySlot = require(script.Parent.Parent.ValueObjects.AbilitySlot)

type SlotKey = CommanderTypes.SlotKey
type AbilitySlotRecord = AbilitySlot.AbilitySlotRecord

--[=[
	@class AbilityService
	Owns the commander slot catalog and stub ability execution.
	@server
]=]
local AbilityService = {}
AbilityService.__index = AbilityService

--[=[
	Creates a new commander ability service.
	@within AbilityService
	@return AbilityService -- The new service instance.
]=]
function AbilityService.new()
	return setmetatable({
		_slots = {} :: { [SlotKey]: AbilitySlotRecord },
	}, AbilityService)
end

--[=[
	Initializes the ability slot map from shared commander config.
	@within AbilityService
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function AbilityService:Init(_registry: any, _name: string)
	-- Build a constant-time lookup table for slot keys used by commands and UI reads.
	for _, definition in CommanderConfig.SLOTS do
		local slotRecord = AbilitySlot.new(definition)
		self._slots[slotRecord.Key] = slotRecord
	end
end

--[=[
	Returns the commander slot definition for a key.
	@within AbilityService
	@param slotKey SlotKey -- The slot key to resolve.
	@return AbilitySlotRecord? -- The matching slot record, or `nil` if missing.
]=]
function AbilityService:GetSlot(slotKey: SlotKey): AbilitySlotRecord?
	return self._slots[slotKey]
end

--[=[
	Checks whether the commander can afford a slot activation.
	@within AbilityService
	@param _userId number -- The player user id.
	@param _slotKey SlotKey -- The slot key being used.
	@return boolean -- `true` until EconomyContext is wired into the command flow.
]=]
function AbilityService:CanAffordAbility(_userId: number, _slotKey: SlotKey): boolean
	-- TODO: Replace this with EconomyContext:SpendEnergy when Commander is fully integrated.
	return true
end

--[=[
	Records a stub commander ability execution event.
	@within AbilityService
	@param userId number -- The player user id.
	@param slotKey SlotKey -- The slot key being used.
]=]
function AbilityService:ExecuteStub(userId: number, slotKey: SlotKey)
	local slot = self._slots[slotKey]
	if slot == nil then
		return
	end

	Result.MentionEvent("CommanderContext:AbilityService", "Executed commander ability stub", {
		userId = userId,
		slotKey = slotKey,
		slotName = slot.DisplayName,
	})
end

return AbilityService
