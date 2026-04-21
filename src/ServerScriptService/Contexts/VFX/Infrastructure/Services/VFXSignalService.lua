--!strict

--[[
	VFXSignalService - Wraps Knit signal firing for server-triggered VFX.

	Handles firing PlayVFX signals to individual players or all clients.
	Keeps signal-firing logic out of the context file.

	Injected with the VFXContext's Client signal table.
]]

local Players = game:GetService("Players")

local VFXSignalService = {}
VFXSignalService.__index = VFXSignalService

--- Constructor (zero-arg; deps resolved in Init)
function VFXSignalService.new()
	return setmetatable({}, VFXSignalService)
end

function VFXSignalService:Init(registry: any, _name: string)
	self._ClientSignals = registry:Get("ClientSignals")
end

--[[
	Fire a VFX signal to a specific player's client.
]]
function VFXSignalService:FireToPlayer(player: Player, effectKey: string, options: { [string]: any }?)
	self._ClientSignals.PlayVFX:Fire(player, effectKey, options or {})
end

--[[
	Fire a VFX signal to all connected clients.
]]
function VFXSignalService:FireToAllClients(effectKey: string, options: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		self._ClientSignals.PlayVFX:Fire(player, effectKey, options or {})
	end
end

return VFXSignalService
