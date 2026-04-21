--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

--[=[
	@class ProcessCombatTick
	Advances combat-owned movement for every active enemy.
	@server
]=]
local ProcessCombatTick = {}
ProcessCombatTick.__index = ProcessCombatTick

function ProcessCombatTick.new()
	return setmetatable({}, ProcessCombatTick)
end

function ProcessCombatTick:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
	self._movementService = registry:Get("CombatMovementService")
end

function ProcessCombatTick:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		if not self._loopService:IsActive() then
			return Ok(false)
		end

		self._movementService:Tick()
		return Ok(true)
	end, "Combat:ProcessCombatTick")
end

return ProcessCombatTick
