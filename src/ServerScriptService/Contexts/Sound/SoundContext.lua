--!strict

--[[
	SoundContext - Server-side Knit service for the Sound context.

	Listens to server-side GameEvents and fires Knit .Client.PlaySound signals
	to the relevant player's client, which then handles actual playback.

	This is a lightweight pass-through: the server resolves which player should
	hear the sound, and the client's SoundController/SoundEngine handles playback.

	Pattern: Lightweight context service (no Domain layer)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

local SoundSignalService = require(script.Parent.Infrastructure.Services.SoundSignalService)

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "ClientSignals",
		Factory = function(service: any, _baseContext: any)
			return service.Client
		end,
	},
	{
		Name = "SoundSignalService",
		Module = SoundSignalService,
		CacheAs = "_signalService",
	},
}

local SoundModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
}

local SoundContext = Knit.CreateService({
	Name = "SoundContext",
	Client = {
		PlaySound = Knit.CreateSignal(),
	},
	Modules = SoundModules,
})

local SoundBaseContext = BaseContext.new(SoundContext)

function SoundContext:KnitInit()
	SoundBaseContext:KnitInit()
end

function SoundContext:KnitStart()
	SoundBaseContext:KnitStart()
	self:_ConnectGameEvents()
	print("[SoundContext] Started")
end

--[[
	Send a sound trigger to a specific player's client.
	The client's SoundController looks up soundKey in SoundMap for playback.
]]
function SoundContext:PlaySoundForPlayer(player: Player, soundKey: string, options: { [string]: any }?)
	self._signalService:FireToPlayer(player, soundKey, options)
end

--[[
	Event-to-sound mapping. Each entry maps a GameEvent to the sound key
	played either for the owning player (user-scoped) or all players (broadcast).
]]
local USER_SCOPED_EVENT_SOUND_MAP = {
	[Events.Forge.CraftingCompleted] = "CraftComplete",
}

local BROADCAST_EVENT_SOUND_MAP = {
	[Events.Run.WaveStarted] = "WaveStart",
	[Events.Run.WaveEnded] = "WaveClear",
	[Events.Base.BaseDestroyed] = "BaseDestroyed",
}

--[[
	Connect to all server-side GameEvents that should trigger client sounds.
]]
function SoundContext:_ConnectGameEvents()
	for eventName, soundKey in USER_SCOPED_EVENT_SOUND_MAP do
		GameEvents.Bus:On(eventName, function(userId: number)
			self:_PlayForUser(userId, soundKey, nil)
		end)
	end

	for eventName, soundKey in BROADCAST_EVENT_SOUND_MAP do
		GameEvents.Bus:On(eventName, function()
			self:_PlayForAllPlayers(soundKey, nil)
		end)
	end
end

function SoundContext:_PlayForUser(userId: number, soundKey: string, options: { [string]: any }?)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self:PlaySoundForPlayer(player, soundKey, options)
	end
end

function SoundContext:_PlayForAllPlayers(soundKey: string, options: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		self:PlaySoundForPlayer(player, soundKey, options)
	end
end

return SoundContext
