--!strict

--[[
    PlayerAnimationController - Knit controller for managing player character animations.

    Handles the player character lifecycle (spawn/respawn) and wires up the custom
    animation system via AnimatePlayerModule. Disables Roblox's default Animate script
    and replaces it with folder-based animations from Assets/Animations/Default/.

    Lifecycle:
      1. KnitStart → connect CharacterAdded / handle existing character
      2. CharacterAdded → disable default Animate, call AnimatePlayerModule.setup()
      3. CharacterRemoving → cleanup previous animation system

    Supports:
      - Core locomotion (idle, walk, run, jump, fall, climb, sit, swim)
      - Server-driven actions via AnimationState attribute
      - Chat command emotes (/e dance, /e wave, etc.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local AnimatePlayerModule = require(script.Parent.AnimatePlayerModule)

local TAG = "[PlayerAnimation]"

local PlayerAnimationController = Knit.CreateController({
	Name = "PlayerAnimationController",
})

---
-- Knit Lifecycle
---

function PlayerAnimationController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self._Cleanup = nil :: (() -> ())?

	registry:InitAll()

	print("PlayerAnimationController initialized")
end

function PlayerAnimationController:KnitStart()
	local registry = self.Registry
	local player = Players.LocalPlayer

	-- Resolve cross-context dependencies
	local SoundController = Knit.GetController("SoundController")
	local VFXController = Knit.GetController("VFXController")
	registry:Register("SoundController", SoundController)
	registry:Register("VFXController", VFXController)

	-- Get SoundEngine from SoundController (deferred — SoundController initialises in KnitStart too)
	local _soundEngine = nil
	local function getSoundEngine()
		if not _soundEngine then
			local ok, sc = pcall(function()
				return Knit.GetController("SoundController")
			end)
			if ok and sc then
				_soundEngine = sc
			end
		end
		return _soundEngine
	end

	-- Get VFXEngine from VFXController
	local _vfxEngine = nil
	local function getVFXEngine()
		if not _vfxEngine then
			local ok, vc = pcall(function()
				return Knit.GetController("VFXController")
			end)
			if ok and vc then
				_vfxEngine = vc:GetVFXEngine()
			end
		end
		return _vfxEngine
	end

	-- Resolve the animations folder from ReplicatedStorage
	local animationsFolder = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("Animations")
	if not animationsFolder then
		warn(TAG, "Assets/Animations folder not found in ReplicatedStorage")
		return
	end

	-- Build shared context (Model is stamped per-character by AnimatePlayerModule.setup)
	local function buildContext(): any
		return {
			Model = nil, -- stamped by AnimatePlayerModule.setup()
			SoundEngine = getSoundEngine(),
			VFXService = getVFXEngine(),
		}
	end

	local function setupCharacter(character: Model)
		-- Clean up previous character's animation system
		self:_CleanupCharacter()

		-- Disable the default Roblox Animate script to prevent conflicts
		self:_DisableDefaultAnimate(character)

		-- Set up custom animations
		local context = buildContext()
		AnimatePlayerModule.setup(character, animationsFolder, context):andThen(function(cleanup)
			if cleanup then
				self._Cleanup = cleanup
			end
		end)
	end

	-- Handle existing character
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end

	-- Handle future character spawns
	player.CharacterAdded:Connect(function(character)
		setupCharacter(character)
	end)

	-- Handle character removal
	player.CharacterRemoving:Connect(function()
		self:_CleanupCharacter()
	end)

	registry:StartOrdered({})

	print("PlayerAnimationController started")
end

---
-- Private Methods
---

--[[
    Disables Roblox's default Animate script on the character.
    Must be called before setting up custom animations.
]]
function PlayerAnimationController:_DisableDefaultAnimate(character: Model)
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
end

--[[
    Cleans up the current character's animation system.
]]
function PlayerAnimationController:_CleanupCharacter()
	if self._Cleanup then
		self._Cleanup()
		self._Cleanup = nil
	end
end

return PlayerAnimationController
