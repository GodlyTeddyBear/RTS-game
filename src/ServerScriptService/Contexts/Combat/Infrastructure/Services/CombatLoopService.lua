--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

type CombatSession = CombatTypes.CombatSession

--[=[
	@class CombatLoopService
	Tracks the current lane combat session.
	@server
]=]
local CombatLoopService = {}
CombatLoopService.__index = CombatLoopService

function CombatLoopService.new()
	local self = setmetatable({}, CombatLoopService)
	self._session = {
		isActive = false,
		currentWaveNumber = 0,
		isEndless = false,
	} :: CombatSession
	return self
end

function CombatLoopService:Init(_registry: any, _name: string)
end

function CombatLoopService:StartCombat(waveNumber: number, isEndless: boolean)
	self._session = {
		isActive = true,
		currentWaveNumber = waveNumber,
		isEndless = isEndless,
	} :: CombatSession
end

function CombatLoopService:StopCombat()
	self._session = {
		isActive = false,
		currentWaveNumber = 0,
		isEndless = false,
	} :: CombatSession
end

function CombatLoopService:SetCurrentWaveNumber(waveNumber: number)
	if not self._session.isActive then
		return
	end

	self._session = {
		isActive = true,
		currentWaveNumber = waveNumber,
		isEndless = self._session.isEndless,
	} :: CombatSession
end

function CombatLoopService:IsActive(): boolean
	return self._session.isActive
end

function CombatLoopService:GetCurrentWaveNumber(): number
	return self._session.currentWaveNumber
end

function CombatLoopService:GetSession(): CombatSession
	return table.clone(self._session) :: CombatSession
end

return CombatLoopService
