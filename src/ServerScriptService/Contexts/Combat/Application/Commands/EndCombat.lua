--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

--[=[
	@class EndCombat
	Cancels combat movement and clears the active session.
	@server
]=]
local EndCombat = {}
EndCombat.__index = EndCombat

function EndCombat.new()
	return setmetatable({}, EndCombat)
end

function EndCombat:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
	self._movementService = registry:Get("CombatMovementService")
end

function EndCombat:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		self._movementService:CancelAll()
		self._loopService:StopCombat()
		return Ok(true)
	end, "Combat:EndCombat")
end

return EndCombat
