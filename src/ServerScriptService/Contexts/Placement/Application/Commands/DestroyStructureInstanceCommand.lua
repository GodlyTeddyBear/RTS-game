--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
	@class DestroyStructureInstanceCommand
	Destroys a spawned structure model without mutating placement records.
	@server
]=]
local DestroyStructureInstanceCommand = {}
DestroyStructureInstanceCommand.__index = DestroyStructureInstanceCommand

function DestroyStructureInstanceCommand.new()
	return setmetatable({}, DestroyStructureInstanceCommand)
end

function DestroyStructureInstanceCommand:Init(registry: any, _name: string)
	self._placementService = registry:Get("PlacementService")
end

function DestroyStructureInstanceCommand:Execute(instanceId: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(type(instanceId) == "number", "InvalidInstanceId", Errors.INVALID_INSTANCE_ID, {
			InstanceId = instanceId,
		})

		self._placementService:DestroyStructure(instanceId)
		return Ok(true)
	end, "Placement:DestroyStructureInstanceCommand")
end

return DestroyStructureInstanceCommand
