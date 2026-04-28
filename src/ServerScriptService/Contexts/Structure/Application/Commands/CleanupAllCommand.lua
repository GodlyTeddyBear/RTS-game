--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok

--[=[
	@class CleanupAllCommand
	Deletes every active structure entity in the isolated world.
	@server
]=]
local CleanupAllCommand = {}
CleanupAllCommand.__index = CleanupAllCommand
setmetatable(CleanupAllCommand, BaseCommand)

--[=[
	Creates a new cleanup command wrapper.
	@within CleanupAllCommand
	@return CleanupAllCommand -- The new command instance.
]=]
function CleanupAllCommand.new()
	local self = BaseCommand.new("Structure", "CleanupAll")
	return setmetatable(self, CleanupAllCommand)
end

--[=[
	Resolves the entity factory used for bulk cleanup.
	@within CleanupAllCommand
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function CleanupAllCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_factory = "StructureEntityFactory",
		_instanceFactory = "StructureInstanceFactory"
	})
end

--[=[
	Deletes every active structure entity.
	@within CleanupAllCommand
	@return Result.Result<boolean> -- Whether the cleanup succeeded.
]=]
function CleanupAllCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		-- Bulk cleanup stays centralized in the entity factory so teardown remains atomic.
		self._instanceFactory:DestroyAll()
		self._factory:DeleteAll()
		self._factory:FlushPendingDeletes()
		return Ok(true)
	end, "Structure:CleanupAllCommand")
end

return CleanupAllCommand


