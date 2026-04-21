--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
	@class StartCombat
	Begins or updates the active combat session for the run.
	@server
]=]
local StartCombat = {}
StartCombat.__index = StartCombat

function StartCombat.new()
	return setmetatable({}, StartCombat)
end

function StartCombat:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
end

function StartCombat:Execute(waveNumber: number, isEndless: boolean): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(waveNumber > 0, "InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER)
		self._loopService:StartCombat(waveNumber, isEndless)
		return Ok(true)
	end, "Combat:StartCombat")
end

return StartCombat
