--!strict

--[[
	PositionalSoundService - Manages 3D spatial audio for worker models.

	Listens for worker models tagged with "AnimatedWorker" via CollectionService.
	When a worker's AnimationState attribute changes to "Mining", attaches a looping
	mining sound to the model. Roblox handles distance attenuation automatically.

	Pattern: Infrastructure layer service (client-only)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
end

function PositionalSoundService:_OnModelAdded(instance: Instance)
	if not instance:IsA("Model") then return end

	local model = instance :: Model
	local entry = {
		Sound = nil :: Sound?,
		Connection = nil :: RBXScriptConnection?,
	}

	-- Listen for AnimationState attribute changes
	entry.Connection = model:GetAttributeChangedSignal("AnimationState"):Connect(function()
		local state = model:GetAttribute("AnimationState")
		self:_HandleAnimationStateChange(model, state, entry)
	end)

	-- Check current state
	local currentState = model:GetAttribute("AnimationState")
	if currentState then
		self:_HandleAnimationStateChange(model, currentState, entry)
	end

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

function PositionalSoundService:_HandleAnimationStateChange(
	model: Model,
	state: string?,
	entry: { Sound: Sound?, Connection: RBXScriptConnection? }
)
	if state == "Mining" then
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
