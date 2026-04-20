--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err = Result.Ok, Result.Err

local Errors = require(script.Parent.Parent.Parent.Errors)
local MachineEligibility = require(script.Parent.Parent.Parent.BuildingDomain.Services.MachineEligibility)

--[=[
	@class GetMachineState
	Builds machine runtime state view for client consumption.
	@server
]=]

--[=[
	@interface TMachineJobView
	@within GetMachineState
	.recipeId string -- Queued recipe identifier.
	.progressSeconds number -- Current elapsed recipe progress.
	.processDurationSeconds number? -- Total duration for recipe, when known.
]=]
export type TMachineJobView = {
	recipeId: string,
	progressSeconds: number,
	processDurationSeconds: number?,
}

--[=[
	@interface TMachineStateView
	@within GetMachineState
	.fuelSecondsRemaining number -- Remaining burn time.
	.queue { TMachineJobView } -- Ordered queue preview with progress.
	.outputItemId string? -- Pending output item identifier.
	.outputQuantity number? -- Pending output quantity.
	.buildingType string? -- Building type at the requested slot.
]=]
export type TMachineStateView = {
	fuelSecondsRemaining: number,
	queue: { TMachineJobView },
	outputItemId: string?,
	outputQuantity: number?,
	buildingType: string?,
}

local GetMachineState = {}
GetMachineState.__index = GetMachineState

--[=[
	Create a machine state query instance.
	@within GetMachineState
	@return any -- New machine state query instance.
]=]
function GetMachineState.new()
	return setmetatable({}, GetMachineState)
end

--[=[
	Initialize query dependencies from registry.
	@within GetMachineState
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function GetMachineState:Init(registry: any, _name: string)
	self._store = registry:Get("MachineRuntimeStore")
	self._persistence = registry:Get("BuildingPersistenceService")
end

--[=[
	Get normalized machine runtime view for a slot.
	@within GetMachineState
	@param player Player -- Player requesting machine state.
	@param zoneName string -- Zone containing the machine slot.
	@param slotIndex number -- One-based machine slot index.
	@return Result.Result<TMachineStateView> -- Success with machine view or validation error.
]=]
function GetMachineState:Execute(player: Player, zoneName: string, slotIndex: number): Result.Result<TMachineStateView>
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

	local queueView: { TMachineJobView } = {}
	for _, job in state.queue do
		local rec = RecipeConfig[job.recipeId]
		table.insert(queueView, {
			recipeId = job.recipeId,
			progressSeconds = job.progressSeconds,
			processDurationSeconds = rec and rec.ProcessDurationSeconds,
		})
	end

	return Ok({
		fuelSecondsRemaining = state.fuelSecondsRemaining,
		queue = queueView,
		outputItemId = state.outputItemId,
		outputQuantity = state.outputQuantity,
		buildingType = slotData.BuildingType,
	})
end

return GetMachineState
