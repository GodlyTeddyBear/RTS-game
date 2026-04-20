--!strict

--[[
	VFXContext - Server-side Knit service for the VFX context.

	Listens to server-side GameEvents and fires Knit Client.PlayVFX signals
	to the relevant player's client, which then handles visual playback.

	This is a lightweight pass-through: the server resolves which player(s)
	should see the effect, and the client's VFXController/VFXEngine handles rendering.

	Pattern: Lightweight context service (no Domain layer), mirrors SoundContext.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

local VFXSignalService = require(script.Parent.Infrastructure.Services.VFXSignalService)

local VFXContext = Knit.CreateService({
	Name = "VFXContext",
	Client = {
		PlayVFX = Knit.CreateSignal(),
	},
})

function VFXContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Raw value registrations
	registry:Register("ClientSignals", self.Client)

	-- Infrastructure Services
	registry:Register("VFXSignalService", VFXSignalService.new(), "Infrastructure")

	registry:InitAll()

	-- Cache refs needed by context handlers
	self._SignalService = registry:Get("VFXSignalService")
end

function VFXContext:KnitStart()
	self.Registry:StartOrdered({ "Infrastructure" })

	self:_ConnectGameEvents()
	print("[VFXContext] Started")
end

---
--- Public API (called by other server contexts)
---

--[[
	Trigger a VFX on a specific player's client.
]]
function VFXContext:PlayVFXForPlayer(player: Player, effectKey: string, options: { [string]: any }?)
	self._SignalService:FireToPlayer(player, effectKey, options)
end

--[[
	Trigger a VFX on all connected clients.
]]
function VFXContext:PlayVFXForAllClients(effectKey: string, options: { [string]: any }?)
	self._SignalService:FireToAllClients(effectKey, options)
end

---
--- Private
---

--[[
	Connect to server-side GameEvents that should trigger client VFX.
	Add connections here as effects are defined.
]]
function VFXContext:_ConnectGameEvents()
	GameEvents.Bus:On(Events.Combat.NPCDied, function(userId: number, _npcId: string, _sourceId: string, _deathType: string)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			-- Example: self:PlayVFXForPlayer(player, "DeathBurst", { Position = ... })
		end
	end)
end

return VFXContext
