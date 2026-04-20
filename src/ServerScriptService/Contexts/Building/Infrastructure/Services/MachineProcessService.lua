--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)

local MachineRuntimeStore = require(script.Parent.Parent.Persistence.MachineRuntimeStore)

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local EPS = 1e-4

--[=[
	@class MachineProcessService
	Advances machine fuel and recipe progress for all active building slots.
	@server
]=]
local MachineProcessService = {}
MachineProcessService.__index = MachineProcessService

export type TMachineProcessService = typeof(setmetatable(
	{} :: {
		_store: any,
		_persistence: any,
	},
	MachineProcessService
))

--[=[
	Create the machine runtime processor with store and persistence dependencies.
	@within MachineProcessService
	@param store any -- Runtime store for per-slot machine state.
	@param persistence any -- Persistence adapter for slot building data.
	@return TMachineProcessService -- New machine process service instance.
]=]
function MachineProcessService.new(store: any, persistence: any): TMachineProcessService
	local self = setmetatable({}, MachineProcessService)
	self._store = store
	self._persistence = persistence
	return self
end

-- Check whether the current slot's building type supports machine processing and fuel burn.
function MachineProcessService:_buildingHasMachineUI(zoneName: string, buildingType: string): boolean
	local zoneDef = BuildingConfig[zoneName]
	local def = zoneDef and zoneDef.Buildings[buildingType]
	return def ~= nil and def.FuelItemId ~= nil and def.FuelBurnDurationSeconds ~= nil
		and def.FuelBurnDurationSeconds > 0
end

-- Merge recipe output into slot output storage, stopping when output type would conflict.
function MachineProcessService:_tryMergeOutput(state: MachineRuntimeStore.TMachineSlotState, recipe: any): boolean
	local outId = recipe.OutputItemId
	local outQ = recipe.OutputQuantity
	if state.outputItemId == nil or state.outputQuantity == nil or (state.outputQuantity :: number) <= 0 then
		state.outputItemId = outId
		state.outputQuantity = outQ
		return true
	end
	if state.outputItemId == outId then
		state.outputQuantity = (state.outputQuantity :: number) + outQ
		return true
	end
	return false
end

-- Advance one machine slot by `dt` seconds while honoring fuel, queue order, and output limits.
function MachineProcessService:_advanceSlot(player: Player, zoneName: string, slotIndex: number, dt: number)
	-- Ignore tiny deltas to avoid floating point churn.
	if dt <= EPS then
		return
	end

	-- Resolve authoritative slot data and skip non-machine buildings.
	local slotData = self._persistence:GetSlotData(player, zoneName, slotIndex)
	if not slotData then
		return
	end
	if not self:_buildingHasMachineUI(zoneName, slotData.BuildingType) then
		return
	end

	local state = self._store:GetState(player, zoneName, slotIndex)
	if not state then
		return
	end

	-- Spend available delta while fuel exists and queued jobs can progress.
	local remaining = dt
	while remaining > EPS do
		if state.fuelSecondsRemaining <= EPS then
			break
		end

		-- Burn fuel when idle to match furnace-style behavior.
		if #state.queue == 0 then
			local burn = math.min(remaining, state.fuelSecondsRemaining)
			state.fuelSecondsRemaining -= burn
			remaining -= burn
			break
		end

		local job = state.queue[1]
		local recipe = RecipeConfig[job.recipeId]
		if not recipe or not recipe.ProcessDurationSeconds or recipe.ProcessDurationSeconds <= 0 then
			-- Drop invalid jobs so the queue can recover automatically.
			table.remove(state.queue, 1)
		else
			local duration = recipe.ProcessDurationSeconds :: number

			-- Finalize jobs that were already complete at loop entry.
			if job.progressSeconds >= duration - EPS then
				if self:_tryMergeOutput(state, recipe) then
					table.remove(state.queue, 1)
				else
					return
				end
			else
				-- Consume time against both fuel and remaining recipe duration.
				local toComplete = duration - job.progressSeconds
				local step = math.min(remaining, state.fuelSecondsRemaining, toComplete)
				state.fuelSecondsRemaining -= step
				job.progressSeconds += step
				remaining -= step

				if job.progressSeconds >= duration - EPS then
					if self:_tryMergeOutput(state, recipe) then
						table.remove(state.queue, 1)
					else
						return
					end
				end
			end
		end
	end

	-- Burn remaining fuel when queue empty (matches furnace wasting fuel while lit)
	if #state.queue == 0 and state.fuelSecondsRemaining > EPS and remaining > EPS then
		local burn = math.min(remaining, state.fuelSecondsRemaining)
		state.fuelSecondsRemaining -= burn
	end
end

--[=[
	Tick all player machine slots using the scheduler delta time.
	@within MachineProcessService
]=]
function MachineProcessService:TickAllPlayers()
	-- Clamp frame time to avoid giant catch-up steps after stalls.
	local dt = ServerScheduler:GetDeltaTime()
	if dt <= EPS then
		return
	end
	dt = math.min(dt, 0.5)

	-- Advance every tracked slot for every connected player.
	for _, player in Players:GetPlayers() do
		local allStates = self._store:GetAllForPlayer(player)
		for key, _ in pairs(allStates) do
			local zoneName, slotIndex = MachineRuntimeStore.ParseSlotKey(key)
			if zoneName and slotIndex then
				self:_advanceSlot(player, zoneName, slotIndex, dt)
			end
		end
	end
end

return MachineProcessService
