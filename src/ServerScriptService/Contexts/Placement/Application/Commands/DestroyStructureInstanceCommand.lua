--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
	@class DestroyStructureInstanceCommand
	Destroys a spawned structure model and clears placement occupancy state.
	@server
]=]
local DestroyStructureInstanceCommand = {}
DestroyStructureInstanceCommand.__index = DestroyStructureInstanceCommand
setmetatable(DestroyStructureInstanceCommand, BaseCommand)

function DestroyStructureInstanceCommand.new()
	local self = BaseCommand.new("Placement", "DestroyStructureInstance")
	return setmetatable(self, DestroyStructureInstanceCommand)
end

function DestroyStructureInstanceCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_placementService = "PlacementService",
		_syncService = "PlacementSyncService"
	})
end

function DestroyStructureInstanceCommand:Start(registry: any, _name: string)
	self._worldContext = registry:Get("WorldContext")
end

function DestroyStructureInstanceCommand:Execute(instanceId: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(type(instanceId) == "number", "InvalidInstanceId", Errors.INVALID_INSTANCE_ID, {
			InstanceId = instanceId,
		})

		local removedRecord = self._syncService:RemovePlacementByInstanceId(instanceId)
		self._placementService:DestroyStructure(instanceId)

		if removedRecord ~= nil then
			local occupancyResult = self._worldContext:SetTileOccupied(removedRecord.coord, false)
			Ensure(occupancyResult.success, "OccupancyReleaseFailed", Errors.OCCUPANCY_RELEASE_FAILED, {
				InstanceId = instanceId,
				Row = removedRecord.coord.row,
				Col = removedRecord.coord.col,
				CauseType = occupancyResult.type,
				CauseMessage = occupancyResult.message,
			})
			Ensure(occupancyResult.value == true, "OccupancyReleaseFailed", Errors.OCCUPANCY_RELEASE_FAILED, {
				InstanceId = instanceId,
				Row = removedRecord.coord.row,
				Col = removedRecord.coord.col,
			})
		end

		return Ok(true)
	end, "Placement:DestroyStructureInstanceCommand")
end

return DestroyStructureInstanceCommand


