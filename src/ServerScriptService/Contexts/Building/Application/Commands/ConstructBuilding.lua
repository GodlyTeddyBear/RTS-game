--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Catch, Try = Result.Ok, Result.Catch, Result.Try
local MentionSuccess = Result.MentionSuccess
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Events = GameEvents.Events

local BuildingId = require(script.Parent.Parent.Parent.BuildingDomain.ValueObjects.BuildingId)

--[=[
	@class ConstructBuilding
	Orchestrates end-to-end building construction workflow.
	@server
]=]
local ConstructBuilding = {}
ConstructBuilding.__index = ConstructBuilding

export type TConstructBuilding = typeof(setmetatable(
	{} :: {
		_constructPolicy: any,
		_entityFactory: any,
		_persistenceService: any,
		_currencyService: any,
		_buildingIdCounter: { Value: number },
	},
	ConstructBuilding
))

--[=[
	Create a construct command with shared building ID counter.
	@within ConstructBuilding
	@param buildingIdCounter { Value: number } -- Shared monotonic building counter.
	@return TConstructBuilding -- New construct command instance.
]=]
function ConstructBuilding.new(buildingIdCounter: { Value: number }): TConstructBuilding
	local self = setmetatable({}, ConstructBuilding)
	self._constructPolicy = nil :: any
	self._entityFactory = nil :: any
	self._persistenceService = nil :: any
	self._currencyService = nil :: any
	self._buildingIdCounter = buildingIdCounter
	return self
end

--[=[
	Initialize command dependencies from registry.
	@within ConstructBuilding
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function ConstructBuilding:Init(registry: any, _name: string)
	self._constructPolicy = registry:Get("ConstructPolicy")
	self._entityFactory = registry:Get("BuildingEntityFactory")
	self._persistenceService = registry:Get("BuildingPersistenceService")
	self._currencyService = registry:Get("BuildingCurrencyService")
end

--[=[
	Execute building construction for a slot.
	@within ConstructBuilding
	@param player Player -- Player requesting construction.
	@param zoneName string -- Zone containing the target slot.
	@param slotIndex number -- One-based target slot index.
	@param buildingType string -- Building type key to construct.
	@return Result.Result<string> -- Success with building ID, or construction error.
]=]
function ConstructBuilding:Execute(
	player: Player,
	zoneName: string,
	slotIndex: number,
	buildingType: string
): Result.Result<string>
	return Catch(function()
		-- Validate preconditions before any state mutation.
		Try(self._constructPolicy:Check(player, zoneName, slotIndex, buildingType))
		Try(self._currencyService:DeductConstructionCost(player, zoneName, buildingType))
		Try(self._persistenceService:SaveBuilding(player, zoneName, slotIndex, buildingType))

		-- Create ECS entity after persistence so sync can realize model state.
		local id = BuildingId.new(player.UserId, self._buildingIdCounter)
		self._entityFactory:CreateBuilding(id:GetId(), player.UserId, zoneName, slotIndex, buildingType)

		if buildingType == "Smelter" then
			GameEvents.Bus:Emit(Events.Guide.SmelterPlaced, player.UserId)
		end

		MentionSuccess("Building:ConstructBuilding:Execute", "Constructed building and registered ECS entity", {
			userId = player.UserId,
			zoneName = zoneName,
			slotIndex = slotIndex,
			buildingType = buildingType,
		})

		return Ok(id:GetId())
	end, "ConstructBuilding:Execute")
end

return ConstructBuilding
