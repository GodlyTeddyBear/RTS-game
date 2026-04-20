--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok
local MentionSuccess = Result.MentionSuccess

local BuildingId = require(script.Parent.Parent.Parent.BuildingDomain.ValueObjects.BuildingId)

--[=[
	@class RestoreBuildings
	Rebuilds ECS building entities from persisted slot data.
	@server
]=]
local RestoreBuildings = {}
RestoreBuildings.__index = RestoreBuildings

export type TRestoreBuildings = typeof(setmetatable(
	{} :: {
		_entityFactory: any,
		_persistenceService: any,
		_buildingIdCounter: { Value: number },
	},
	RestoreBuildings
))

--[=[
	Create a restore command with shared building ID counter.
	@within RestoreBuildings
	@param buildingIdCounter { Value: number } -- Shared monotonic building counter.
	@return TRestoreBuildings -- New restore command instance.
]=]
function RestoreBuildings.new(buildingIdCounter: { Value: number }): TRestoreBuildings
	local self = setmetatable({}, RestoreBuildings)
	self._entityFactory = nil :: any
	self._persistenceService = nil :: any
	self._buildingIdCounter = buildingIdCounter
	return self
end

--[=[
	Initialize command dependencies from registry.
	@within RestoreBuildings
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function RestoreBuildings:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("BuildingEntityFactory")
	self._persistenceService = registry:Get("BuildingPersistenceService")
end

--[=[
	Recreate ECS entities from persisted buildings for one player.
	@within RestoreBuildings
	@param player Player -- Player whose buildings should be restored.
	@return Result.Result<nil> -- Success when all persisted buildings are restored.
]=]
function RestoreBuildings:Execute(player: Player): Result.Result<nil>
	local allBuildings = self._persistenceService:GetAllBuildings(player)
	local restoredCount = 0

	for zoneName, slots in allBuildings do
		local zoneRestoredCount = 0
		for slotIndex, slotData in slots do
			local id = BuildingId.new(player.UserId, self._buildingIdCounter)
			local entity = self._entityFactory:CreateBuilding(
				id:GetId(),
				player.UserId,
				zoneName,
				slotIndex,
				slotData.BuildingType
			)

			-- Replay level progression so ECS level component matches persisted level.
			if slotData.Level > 1 then
				for _ = 1, slotData.Level - 1 do
					self._entityFactory:IncrementLevel(entity)
				end
			end
			restoredCount += 1
			zoneRestoredCount += 1
		end

		MentionSuccess("Building:RestoreBuildings:Execute", "Restored persisted zone building entries", {
			userId = player.UserId,
			zoneName = zoneName,
			restoredCount = zoneRestoredCount,
		})
	end
	MentionSuccess("Building:RestoreBuildings:Execute", "Restored building entities from persisted profile state", {
		userId = player.UserId,
		restoredCount = restoredCount,
	})

	return Ok(nil)
end

return RestoreBuildings
