--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err, Try = Result.Ok, Result.Err, Result.Try
local MentionSuccess = Result.MentionSuccess
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

local Errors = require(script.Parent.Parent.Parent.Errors)
local MachineEligibility = require(script.Parent.Parent.Parent.BuildingDomain.Services.MachineEligibility)

local Events = GameEvents.Events

--[=[
	@class MachineClaimOutput
	Claims completed machine output and deposits it into player inventory.
	@server
]=]
local MachineClaimOutput = {}
MachineClaimOutput.__index = MachineClaimOutput

--[=[
	Create a machine output claim command instance.
	@within MachineClaimOutput
	@return any -- New machine claim command instance.
]=]
function MachineClaimOutput.new()
	return setmetatable({}, MachineClaimOutput)
end

--[=[
	Initialize command dependencies from registry.
	@within MachineClaimOutput
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function MachineClaimOutput:Init(registry: any, _name: string)
	self._registry = registry
	self._store = registry:Get("MachineRuntimeStore")
	self._persistence = registry:Get("BuildingPersistenceService")
end

--[=[
	Resolve inventory context dependency after ordered startup.
	@within MachineClaimOutput
]=]
function MachineClaimOutput:Start()
	self._inventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Claim pending machine output into player inventory.
	@within MachineClaimOutput
	@param player Player -- Player claiming machine output.
	@param zoneName string -- Zone containing the machine slot.
	@param slotIndex number -- One-based machine slot index.
	@return Result.Result<nil> -- Success when output is claimed and cleared.
]=]
function MachineClaimOutput:Execute(player: Player, zoneName: string, slotIndex: number): Result.Result<nil>
	local slotData = self._persistence:GetSlotData(player, zoneName, slotIndex)
	if not slotData then
		return Err("SlotEmpty", Errors.SLOT_EMPTY)
	end

	if not MachineEligibility.SlotIsFuelMachine(zoneName, slotData.BuildingType) then
		return Err("NotFuelMachine", Errors.NOT_FUEL_MACHINE)
	end

	local state = self._store:GetState(player, zoneName, slotIndex)
	if not state then
		return Err("NoProfile", Errors.NO_PROFILE_DATA)
	end

	local itemId = state.outputItemId
	local qty = state.outputQuantity
	if itemId == nil or qty == nil or qty <= 0 then
		return Err("NoOutput", Errors.NO_MACHINE_OUTPUT)
	end

	Try(self._inventoryContext:AddItemToInventory(player.UserId, itemId, qty))

	GameEvents.Bus:Emit(Events.Crafting.CraftingCompleted, player.UserId, itemId, itemId, qty)

	if itemId == ItemId.Charcoal then
		GameEvents.Bus:Emit(Events.Guide.CharcoalCrafted, player.UserId)
	end

	state.outputItemId = nil
	state.outputQuantity = nil

	MentionSuccess("Building:MachineClaimOutput", "Claimed machine output", {
		userId = player.UserId,
		itemId = itemId,
		quantity = qty,
	})

	return Ok(nil)
end

return MachineClaimOutput
