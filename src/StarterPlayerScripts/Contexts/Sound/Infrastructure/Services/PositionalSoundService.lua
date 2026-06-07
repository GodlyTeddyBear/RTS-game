--!strict

--[[
	PositionalSoundService - Manages 3D spatial audio for worker models.

	Listens for worker models tagged with "AnimatedWorker" and animation marker events.
	Animation state lives in EntityContext; this service only reacts to marker payloads
	emitted by AnimationController.

	Pattern: Infrastructure layer service (client-only)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SoundIds = require(ReplicatedStorage.Contexts.Sound.Config.SoundIds)

local PositionalSoundService = {}
PositionalSoundService.__index = PositionalSoundService

local TAG_NAME = "AnimatedWorker"
local ROLLOFF_MIN = 10
local ROLLOFF_MAX = 80

function PositionalSoundService.new(ambientSoundGroup: SoundGroup?)
	local self = setmetatable({}, PositionalSoundService)
	self._AmbientSoundGroup = ambientSoundGroup
	self._TrackedModels = {} :: { [Model]: { Sound: Sound?, Connection: RBXScriptConnection? } }
	self._TagAddedConnection = nil :: RBXScriptConnection?
	self._TagRemovedConnection = nil :: RBXScriptConnection?
	self._MarkerCleanup = nil :: (() -> ())?
	return self
end

function PositionalSoundService:Start()
	-- Track existing tagged models
	for _, model in CollectionService:GetTagged(TAG_NAME) do
		self:_OnModelAdded(model)
	end

	-- Listen for new/removed tagged models
	self._TagAddedConnection = CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(function(instance)
		self:_OnModelAdded(instance)
	end)

	self._TagRemovedConnection = CollectionService:GetInstanceRemovedSignal(TAG_NAME):Connect(function(instance)
		self:_OnModelRemoved(instance)
	end)

	local ok, animationController = pcall(function()
		return Knit.GetController("AnimationController")
	end)
	if ok and animationController ~= nil and type(animationController.ObserveMarker) == "function" then
		self._MarkerCleanup = animationController:ObserveMarker(function(payload)
			self:_HandleAnimationMarker(payload)
		end)
	end
end

function PositionalSoundService:_OnModelAdded(instance: Instance)
	if not instance:IsA("Model") then return end

	local model = instance :: Model
	local entry = {
		Sound = nil :: Sound?,
		Connection = nil :: RBXScriptConnection?,
	}

	self._TrackedModels[model] = entry
end

function PositionalSoundService:_OnModelRemoved(instance: Instance)
	if not instance:IsA("Model") then return end

	local model = instance :: Model
	local entry = self._TrackedModels[model]
	if not entry then return end

	if entry.Connection then
		entry.Connection:Disconnect()
	end

	if entry.Sound and entry.Sound.Parent then
		entry.Sound:Destroy()
	end

	self._TrackedModels[model] = nil
end

function PositionalSoundService:_HandleAnimationMarker(payload: any)
	if type(payload) ~= "table" or typeof(payload.Model) ~= "Instance" or not payload.Model:IsA("Model") then
		return
	end

	local entry = self._TrackedModels[payload.Model]
	if entry == nil then
		return
	end

	if payload.MarkerName == "MiningLoopStart" or (payload.MarkerName == "ActionStarted" and payload.ActionId == "Extract") then
		self:_SetMiningLoop(payload.Model, true, entry)
	elseif payload.MarkerName == "MiningLoopStop" or (payload.MarkerName == "ActionStopped" and payload.ActionId == "Extract") then
		self:_SetMiningLoop(payload.Model, false, entry)
	end
end

function PositionalSoundService:_SetMiningLoop(
	model: Model,
	enabled: boolean,
	entry: { Sound: Sound?, Connection: RBXScriptConnection? }
)
	if enabled then
		-- Start mining loop sound if not already playing
		if not entry.Sound or not entry.Sound.Parent then
			local soundId = SoundIds.Ambient.MiningLoop
			if soundId == "rbxassetid://0" or soundId == "" then return end

			local sound = Instance.new("Sound")
			sound.SoundId = soundId
			sound.Looped = true
			sound.Volume = 0.6
			sound.RollOffMinDistance = ROLLOFF_MIN
			sound.RollOffMaxDistance = ROLLOFF_MAX
			sound.RollOffMode = Enum.RollOffMode.InverseTapered

			if self._AmbientSoundGroup then
				sound.SoundGroup = self._AmbientSoundGroup
			end

			-- Attach to the model's PrimaryPart for spatial positioning
			local parent = model.PrimaryPart or model
			sound.Parent = parent
			sound:Play()

			entry.Sound = sound
		end
	else
		-- Stop mining sound
		if entry.Sound and entry.Sound.Parent then
			entry.Sound:Stop()
			entry.Sound:Destroy()
			entry.Sound = nil
		end
	end
end

function PositionalSoundService:Cleanup()
	if self._MarkerCleanup ~= nil then
		self._MarkerCleanup()
		self._MarkerCleanup = nil
	end
	if self._TagAddedConnection then
		self._TagAddedConnection:Disconnect()
		self._TagAddedConnection = nil
	end

	if self._TagRemovedConnection then
		self._TagRemovedConnection:Disconnect()
		self._TagRemovedConnection = nil
	end

	for model, entry in self._TrackedModels do
		if entry.Connection then
			entry.Connection:Disconnect()
		end
		if entry.Sound and entry.Sound.Parent then
			entry.Sound:Destroy()
		end
	end

	self._TrackedModels = {}
end

return PositionalSoundService
