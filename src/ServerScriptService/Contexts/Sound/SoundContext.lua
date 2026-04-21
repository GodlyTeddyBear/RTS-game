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
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

local SoundContext = Knit.CreateService({
	Name = "SoundContext",
	Client = {
		PlaySound = Knit.CreateSignal(),
	},
})

function SoundContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	registry:InitAll()
end

function SoundContext:KnitStart()
	self.Registry:StartAll()

	self:_ConnectGameEvents()
	print("[SoundContext] Started")
end

--[[
	Send a sound trigger to a specific player's client.
	The client's SoundController looks up soundKey in SoundMap for playback.
]]
function SoundContext:PlaySoundForPlayer(player: Player, soundKey: string, options: {}?)
	self.Client.PlaySound:Fire(player, soundKey, options or {})
end

--[[
	Event-to-sound mapping. Each entry maps a GameEvent to the sound key
	played on the owning player's client. All events emit userId as arg #1.
]]
local EVENT_SOUND_MAP = {}

--[[
	Connect to all server-side GameEvents that should trigger client sounds.
]]
function SoundContext:_ConnectGameEvents()
	for event, soundKey in EVENT_SOUND_MAP do
		GameEvents.Bus:On(event, function(userId: number, ...)
			local args = { ... }
			local options = nil
			if event == Events.Worker.MiningCompleted then
				options = { WorkerId = args[1] }
			end
			self:_PlayForUser(userId, soundKey, options)
		end)
	end
end

function SoundContext:_PlayForUser(userId: number, soundKey: string, options: {}?)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self:PlaySoundForPlayer(player, soundKey, options)
	end
end

return SoundContext
