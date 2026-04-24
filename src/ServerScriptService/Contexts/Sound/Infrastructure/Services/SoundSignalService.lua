--!strict

--[[
	SoundSignalService - Wraps Knit signal firing for server-triggered sounds.

	Handles firing PlaySound signals to individual players.
	Keeps signal-firing logic out of the context file.

	Injected with the SoundContext's Client signal table.
]]

local SoundSignalService = {}
SoundSignalService.__index = SoundSignalService

function SoundSignalService.new()
	return setmetatable({}, SoundSignalService)
end

function SoundSignalService:Init(registry: any, _name: string)
	self._clientSignals = registry:Get("ClientSignals")
end

function SoundSignalService:FireToPlayer(player: Player, soundKey: string, options: { [string]: any }?)
	self._clientSignals.PlaySound:Fire(player, soundKey, options or {})
end

return SoundSignalService
