--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Catch, Try = Result.Ok, Result.Catch, Result.Try
local MentionSuccess = Result.MentionSuccess

--[=[
	@class UpgradeBuilding
	Orchestrates end-to-end building upgrade workflow.
	@server
]=]
local UpgradeBuilding = {}
UpgradeBuilding.__index = UpgradeBuilding

export type TUpgradeBuilding = typeof(setmetatable(
	{} :: {
		_upgradePolicy: any,
		_entityFactory: any,
		_persistenceService: any,
	},
	UpgradeBuilding
))

--[=[
	Create an upgrade command instance.
	@within UpgradeBuilding
	@return TUpgradeBuilding -- New upgrade command instance.
]=]
function UpgradeBuilding.new(): TUpgradeBuilding
	local self = setmetatable({}, UpgradeBuilding)
	self._upgradePolicy = nil :: any
	self._entityFactory = nil :: any
	self._persistenceService = nil :: any
	return self
end

--[=[
	Initialize command dependencies from registry.
	@within UpgradeBuilding
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function UpgradeBuilding:Init(registry: any, _name: string)
	self._upgradePolicy = registry:Get("UpgradePolicy")
	self._entityFactory = registry:Get("BuildingEntityFactory")
	self._persistenceService = registry:Get("BuildingPersistenceService")
end

--[=[
	Execute a building upgrade for the target slot.
	@within UpgradeBuilding
	@param player Player -- Player requesting upgrade.
	@param zoneName string -- Zone containing the target slot.
	@param slotIndex number -- One-based target slot index.
	@return Result.Result<nil> -- Success when upgrade is persisted and entity updated.
]=]
function UpgradeBuilding:Execute(
	player: Player,
	zoneName: string,
	slotIndex: number
): Result.Result<nil>
	return Catch(function()
		-- Validate preconditions and persist level increment first.
		Try(self._upgradePolicy:Check(player, zoneName, slotIndex))
		Try(self._persistenceService:IncrementLevel(player, zoneName, slotIndex))

		-- Keep ECS entity level aligned with persisted data when entity exists.
		local entity = self._entityFactory:FindBuildingBySlot(player.UserId, zoneName, slotIndex)
		if entity then
			self._entityFactory:IncrementLevel(entity)
		end
		MentionSuccess("Building:UpgradeBuilding:Execute", "Upgraded building level for slot", {
			userId = player.UserId,
			zoneName = zoneName,
			slotIndex = slotIndex,
		})

		return Ok(nil)
	end, "UpgradeBuilding:Execute")
end

return UpgradeBuilding
