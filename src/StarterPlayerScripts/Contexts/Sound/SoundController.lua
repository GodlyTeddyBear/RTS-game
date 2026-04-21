--!strict

--[[
	SoundController - Client-side Knit controller for the Sound context.

	Wires together:
	- SoundtrackController for core playback
	- PositionalSoundService for 3D spatial audio on worker models
	- GameEvents listeners for client-side UI sounds
	- Knit remote signal listener for server-triggered sounds
	- SoundMap for event-to-sound resolution

	Pattern: Lightweight context controller (no Domain layer)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

local SoundtrackController = require(ReplicatedStorage.Utilities.SoundtrackController)
local PositionalSoundService = require(script.Parent.Infrastructure.PositionalSoundService)
local SoundMap = require(script.Parent.Config.SoundMap)

-- Default volumes matching SoundtrackController.new() defaults
local DEFAULT_VOLUMES = {
	Master = 1,
	Music = 0.8,
	SFX = 1,
	UI = 1,
	Ambient = 0.6,
}

local UI_COOLDOWN = 0.1

local SoundController = Knit.CreateController({
	Name = "SoundController",
})

function SoundController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self._Soundtrack = SoundtrackController.new()
	self._PositionalSoundService = PositionalSoundService.new(
		self._Soundtrack.AmbientGroup
	)

	self._VolumeState = {
		Master = DEFAULT_VOLUMES.Master,
		Music = DEFAULT_VOLUMES.Music,
		SFX = DEFAULT_VOLUMES.SFX,
		UI = DEFAULT_VOLUMES.UI,
		Ambient = DEFAULT_VOLUMES.Ambient,
	}
	self._LastPlayTimes = {}

	registry:Register("SoundtrackController", self._Soundtrack, "Infrastructure")
	registry:Register("PositionalSoundService", self._PositionalSoundService, "Infrastructure")

	registry:InitAll()
end

function SoundController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local SoundContext = Knit.GetService("SoundContext")
	registry:Register("SoundContext", SoundContext)

	-- Listen for server-triggered sounds via Knit remote signal
	SoundContext.PlaySound:Connect(function(soundKey: string, options: any)
		self:_HandleServerSound(soundKey, options)
	end)

	-- Connect client-side GameEvents (UI sounds)
	self:_ConnectClientEvents()

	registry:StartOrdered({ "Infrastructure" })

	print("[SoundController] Started")
end

--[[
	Handle a sound triggered by the server.
	Looks up the soundKey in SoundMap and plays via SoundtrackController.
]]
function SoundController:_HandleServerSound(soundKey: string, options: any)
	local mapping = SoundMap[soundKey]
	if not mapping then
		warn("[SoundController] Unknown server sound key:", soundKey)
		return
	end

	local opts = options or {}
	local playOptions = {
		Volume = opts.Volume or mapping.Volume,
		PlaybackSpeed = opts.PlaybackSpeed or mapping.PlaybackSpeed,
	}

	if mapping.Category == "SFX" then
		local workerId = opts.WorkerId
		if workerId then
			local basePart = self:_ResolveWorkerPart(workerId)
			if basePart then
				self:PlaySFXAt(mapping.SoundId, basePart, playOptions)
			end
			return
		end
		self._Soundtrack:PlaySFX(mapping.SoundId, playOptions)
	elseif mapping.Category == "UI" then
		self:_PlayUI(mapping.SoundId, mapping.Cooldown, playOptions)
	end
end

function SoundController:_ResolveWorkerPart(workerId: string): BasePart?
	local CollectionService = game:GetService("CollectionService")
	for _, instance in CollectionService:GetTagged("AnimatedWorker") do
		if instance:IsA("Model") then
			local attr = instance:GetAttribute("WorkerId")
			if attr == workerId then
				return (instance :: Model).PrimaryPart
			end
		end
	end
	return nil
end

--[[
	Play a UI sound through the SFX group with UI volume scaling and cooldown.
]]
function SoundController:_PlayUI(soundId: string, cooldown: number?, options: { Volume: number?, PlaybackSpeed: number? }?)
	local now = os.clock()
	local minCooldown = cooldown or UI_COOLDOWN
	local lastTime = self._LastPlayTimes[soundId]
	if lastTime and (now - lastTime) < minCooldown then
		return
	end
	self._LastPlayTimes[soundId] = now

	local opts = options or {}
	self._Soundtrack:PlaySFX(soundId, {
		Volume = (opts.Volume or 1) * self._VolumeState.UI,
		PlaybackSpeed = opts.PlaybackSpeed,
	})
end

--[[
	Play a spatial SFX attached to a BasePart. Parented to SFXGroup for volume grouping.
]]
function SoundController:PlaySFXAt(soundId: string, basePart: BasePart, options: { Volume: number?, PlaybackSpeed: number?, RollOffMin: number?, RollOffMax: number? }?)
	local opts = options or {}
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.SoundGroup = self._Soundtrack.SFXGroup
	sound.Volume = opts.Volume or 1
	sound.PlaybackSpeed = opts.PlaybackSpeed or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = opts.RollOffMin or 10
	sound.RollOffMaxDistance = opts.RollOffMax or 80
	sound.Parent = basePart
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

--[[
	Connect to client-side GameEvents for UI sounds.
]]
function SoundController:_ConnectClientEvents()
	GameEvents.Bus:On(Events.UI.ButtonClicked, function(_variant: string)
		self:_PlayFromMap("ButtonClicked")
	end)

	GameEvents.Bus:On(Events.UI.MenuOpened, function(_menuName: string)
		self:_PlayFromMap("MenuOpened")
	end)

	GameEvents.Bus:On(Events.UI.MenuClosed, function(_menuName: string)
		self:_PlayFromMap("MenuClosed")
	end)

	GameEvents.Bus:On(Events.UI.TabSwitched, function(_tabName: string)
		self:_PlayFromMap("TabSwitched")
	end)

	GameEvents.Bus:On(Events.UI.ErrorOccurred, function(_errorType: string)
		self:_PlayFromMap("ErrorOccurred")
	end)

	GameEvents.Bus:On(Events.Inventory.ItemBought, function()
		self:_PlayFromMap("ItemBought")
	end)

	GameEvents.Bus:On(Events.Inventory.ItemSoldClient, function()
		self:_PlayFromMap("ItemSoldClient")
	end)

	GameEvents.Bus:On(Events.Commission.CommissionAcceptedClient, function()
		self:_PlayFromMap("CommissionAcceptedClient")
	end)

	GameEvents.Bus:On(Events.Commission.CommissionDeliveredClient, function()
		self:_PlayFromMap("CommissionDeliveredClient")
	end)
end

--[[
	Look up a key in SoundMap and play the appropriate sound.
]]
function SoundController:_PlayFromMap(mapKey: string)
	local mapping = SoundMap[mapKey]
	if not mapping then return end

	local playOptions = {
		Volume = mapping.Volume,
		PlaybackSpeed = mapping.PlaybackSpeed,
	}

	if mapping.Category == "SFX" then
		self._Soundtrack:PlaySFX(mapping.SoundId, playOptions)
	elseif mapping.Category == "UI" then
		self:_PlayUI(mapping.SoundId, mapping.Cooldown, playOptions)
	end
end

---
--- Public API (for hooks and external use)
---

--[[
	Play a sound by SoundMap key. Falls back to treating the key as a direct asset ID
	if no mapping is found. Used by action contexts and CombatEventDispatcher.
]]
function SoundController:PlaySFX(soundKey: string, options: any?)
	local mapping = SoundMap[soundKey]
	if not mapping then
		self._Soundtrack:PlaySFX(soundKey, options)
		return
	end
	local playOptions = {
		Volume = (options and options.Volume) or mapping.Volume,
		PlaybackSpeed = (options and options.PlaybackSpeed) or mapping.PlaybackSpeed,
	}
	if mapping.Category == "UI" then
		self:_PlayUI(mapping.SoundId, mapping.Cooldown, playOptions)
	else
		self._Soundtrack:PlaySFX(mapping.SoundId, playOptions)
	end
end

--[[
	Set volume for a category.
]]
function SoundController:SetVolume(category: string, volume: number, tweenDuration: number?)
	self._VolumeState[category] = volume
	if category == "Master" then
		self._Soundtrack:SetMasterVolume(volume, tweenDuration)
	elseif category == "Music" then
		self._Soundtrack:SetMusicVolume(volume, tweenDuration)
	elseif category == "SFX" then
		self._Soundtrack:SetSFXVolume(volume, tweenDuration)
	elseif category == "Ambient" then
		self._Soundtrack:SetAmbientVolume(volume, tweenDuration)
	end
	-- "UI" is stored in _VolumeState only; applied as a scalar in _PlayUI
end

--[[
	Get current volume for a category.
]]
function SoundController:GetVolume(category: string): number
	return self._VolumeState[category] or 0
end

--[[
	Play music track.
]]
function SoundController:PlayMusic(soundId: string, options: { Volume: number?, Loop: boolean?, CrossFade: boolean? }?)
	local trackInfo = self._Soundtrack:GetCurrentTrackInfo()
	if trackInfo and trackInfo.isPlaying then
		self._Soundtrack:CrossFadeToMusic(soundId, options)
	else
		self._Soundtrack:PlayMusic(soundId, options)
	end
end

--[[
	Stop current music.
]]
function SoundController:StopMusic(fadeOut: boolean?)
	if fadeOut == false then
		self._Soundtrack:StopMusic()
	else
		self._Soundtrack:FadeOutMusic()
	end
end

--[[
	Enable/disable all sounds.
]]
function SoundController:SetEnabled(enabled: boolean)
	if enabled then
		self._Soundtrack:Enable()
	else
		self._Soundtrack:Disable()
	end
end

--[[
	Get the underlying SoundtrackController instance (for injection into action contexts).
]]
function SoundController:GetSoundtrackController()
	return self._Soundtrack
end

return SoundController
