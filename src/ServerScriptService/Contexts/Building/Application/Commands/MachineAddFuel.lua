--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err, Try, Ensure = Result.Ok, Result.Err, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

local Errors = require(script.Parent.Parent.Parent.Errors)
local MachineEligibility = require(script.Parent.Parent.Parent.BuildingDomain.Services.MachineEligibility)

--[=[
	@class MachineAddFuel
	Consumes inventory fuel and adds burn time to machine runtime state.
	@server
]=]
local MachineAddFuel = {}
MachineAddFuel.__index = MachineAddFuel

--[=[
	Create a machine fuel command instance.
	@within MachineAddFuel
	@return any -- New machine fuel command instance.
]=]
function MachineAddFuel.new()
	return setmetatable({}, MachineAddFuel)
end

--[=[
	Initialize command dependencies from registry.
	@within MachineAddFuel
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function MachineAddFuel:Init(registry: any, _name: string)
	self._registry = registry
	self._store = registry:Get("MachineRuntimeStore")
	self._persistence = registry:Get("BuildingPersistenceService")
end

--[=[
	Resolve inventory context dependency after ordered startup.
	@within MachineAddFuel
]=]
function MachineAddFuel:Start()
	self._inventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Consume fuel items and add equivalent burn time to machine state.
	@within MachineAddFuel
	@param player Player -- Player requesting fuel addition.
	@param zoneName string -- Zone containing the machine slot.
	@param slotIndex number -- One-based machine slot index.
	@param quantity number -- Fuel item quantity to consume.
	@return Result.Result<nil> -- Success when fuel is consumed and burn time is added.
]=]
function MachineAddFuel:Execute(player: Player, zoneName: string, slotIndex: number, quantity: number): Result.Result<nil>
	Ensure(quantity > 0, "InvalidQuantity", "Quantity must be positive")

	local slotData = self._persistence:GetSlotData(player, zoneName, slotIndex)
	if not slotData then
		return Err("SlotEmpty", Errors.SLOT_EMPTY)
	end

	local def = MachineEligibility.GetMachineDefForSlot(zoneName, slotData.BuildingType)
	if not def or not def.FuelItemId or not def.FuelBurnDurationSeconds then
		return Err("NotFuelMachine", Errors.NOT_FUEL_MACHINE)
	end

	local fuelItemId = def.FuelItemId :: string
	local burnPer = def.FuelBurnDurationSeconds :: number

	-- Remove fuel from smallest matching stacks first to minimize fragmentation.
	local invState = Try(self._inventoryContext:GetPlayerInventory(player.UserId))
	local remaining = quantity
	local matchingSlots: { { SlotIndex: number, Quantity: number } } = {}
	for slotIdx, slot in pairs(invState.Slots) do
		if slot and slot.ItemId == fuelItemId then
			table.insert(matchingSlots, { SlotIndex = slotIdx, Quantity = slot.Quantity })
		end
	end
	table.sort(matchingSlots, function(a, b)
		return a.Quantity < b.Quantity
	end)

	for _, info in matchingSlots do
		if remaining <= 0 then
			break
		end
		local take = math.min(remaining, info.Quantity)
		Try(self._inventoryContext:RemoveItemFromInventory(player.UserId, info.SlotIndex, take))
		remaining -= take
	end

	if remaining > 0 then
		return Err("InsufficientFuel", Errors.INSUFFICIENT_FUEL_IN_INVENTORY)
	end

	local state = self._store:GetState(player, zoneName, slotIndex)
	if not state then
		return Err("NoProfile", Errors.NO_PROFILE_DATA)
	end

	state.fuelSecondsRemaining += quantity * burnPer

	MentionSuccess("Building:MachineAddFuel", "Added fuel to machine", {
		userId = player.UserId,
		zoneName = zoneName,
		slotIndex = slotIndex,
		quantity = quantity,
	})

	return Ok(nil)
end

return MachineAddFuel
