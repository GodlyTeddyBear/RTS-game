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
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)

local VFXSignalService = require(script.Parent.Infrastructure.Services.VFXSignalService)

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "ClientSignals",
		Factory = function(service: any, _baseContext: any)
			return service.Client
		end,
	},
	{
		Name = "VFXSignalService",
		Module = VFXSignalService,
		CacheAs = "_signalService",
	},
}

local VFXModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
}

local VFXContext = Knit.CreateService({
	Name = "VFXContext",
	Client = {
		PlayVFX = Knit.CreateSignal(),
	},
	Modules = VFXModules,
})

local VFXBaseContext = BaseContext.new(VFXContext)

function VFXContext:KnitInit()
	VFXBaseContext:KnitInit()
end

function VFXContext:KnitStart()
	VFXBaseContext:KnitStart()
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
	self._signalService:FireToPlayer(player, effectKey, options)
end

--[[
	Trigger a VFX on all connected clients.
]]
function VFXContext:PlayVFXForAllClients(effectKey: string, options: { [string]: any }?)
	self._signalService:FireToAllClients(effectKey, options)
end

---
--- Private
---

--[[
	Connect to server-side GameEvents that should trigger client VFX.
	Add connections here as effects are defined.
]]
function VFXContext:_ConnectGameEvents() end

return VFXContext
