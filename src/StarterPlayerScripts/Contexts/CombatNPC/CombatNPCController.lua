--!strict

--[[
    CombatNPCController - Client-side Knit controller for combat NPC animations
    and server-sourced combat events.

    Responsibilities:
      1. Detect combat NPC models via CollectionService ("CombatNPC" tag)
      2. Set up AnimateCombatNPCModule for animation playback + marker events
      3. Maintain an NPC model registry (NPCId → Model)
      4. Subscribe to CombatContext.NPCEvent for server→client gameplay events
      5. Route events to CombatEventDispatcher for SFX/VFX/custom handlers
      6. Provide CombatService + NPCId in action context so BaseAction can
         fire client→server animation callbacks (e.g., ActivateHitbox)

    Two parallel event channels:
      - Animation markers (ActionEventRouter) → animation-timed SFX/VFX + server callbacks
      - Server events (CombatEventDispatcher) → gameplay-timed effects (damage, death, etc.)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

-- Animation module
local AnimateCombatNPCModule = require(script.Parent.AnimateCombatNPCModule)

-- Action system
local ActionRegistry = require(ReplicatedStorage.Utilities.ActionSystem.ActionRegistry)
local AttackAction = require(script.Parent.Actions.AttackAction)
local BlockAction = require(script.Parent.Actions.BlockAction)

-- Event dispatcher
local CombatEventDispatcher = require(script.Parent.Infrastructure.CombatEventDispatcher)

-- Billboard service
local NPCBillboardService = require(script.Parent.Infrastructure.NPCBillboardService)

local TAG = "CombatNPC"

local CombatNPCController = Knit.CreateController({
	Name = "CombatNPCController",
})

---
-- Knit Lifecycle
---

function CombatNPCController:KnitInit()
	-- Register combat action classes
	-- All weapon-specific attack states share the same AttackAction
	-- (Strike keyframe fires ActivateHitbox regardless of weapon type)
	local attackAction = AttackAction.new()
	ActionRegistry.Register("Attack", attackAction)
	ActionRegistry.Register("MeleeAttack", attackAction)
	ActionRegistry.Register("RangedAttack", attackAction)
	ActionRegistry.Register("SwordAttack", attackAction)
	ActionRegistry.Register("DaggerAttack", attackAction)
	ActionRegistry.Register("StaffAttack", attackAction)
	ActionRegistry.Register("PunchAttack", attackAction)

	local blockAction = BlockAction.new()
	ActionRegistry.Register("Blocking", blockAction)

	-- Registry for local sub-services
	self._Registry = Registry.new("Client")
	self._Registry:Register("CombatEventDispatcher", CombatEventDispatcher.new(), "Infrastructure")
	self._Registry:Register("NPCBillboardService", NPCBillboardService.new(), "Infrastructure")

	-- Init all
	self._Registry:InitAll()

	-- Cache refs
	self._EventDispatcher = self._Registry:Get("CombatEventDispatcher")
	self._BillboardService = self._Registry:Get("NPCBillboardService")

	-- Track active cleanup functions per model
	self._ActiveCleanups = {} :: { [Model]: () -> () }

	print("[CombatNPCController] Initialized")
end

function CombatNPCController:KnitStart()
	-- Get CombatContext server service proxy (for AnimationCallback)
	local CombatService = Knit.GetService("CombatContext")

	-- Start sub-services (CombatEventDispatcher resolves SoundController + VFXController internally)
	self._Registry:StartOrdered({ "Infrastructure", "Application" })

	-- Get VFXEngine from VFXController (needed for buildContext)
	local VFXController = Knit.GetController("VFXController")

	-- Get SoundEngine from SoundController (deferred — SoundController initialises in KnitStart too)
	local _soundEngine = nil
	local function getSoundEngine()
		if not _soundEngine then
			local SoundController = Knit.GetController("SoundController")
			_soundEngine = SoundController
		end
		return _soundEngine
	end

	-- Subscribe to server→client combat events
	CombatService.NPCEvent:Connect(function(events: { any })
		self._EventDispatcher:Dispatch(events)
	end)

	-- Build shared context table per NPC.
	-- NPCId is read lazily via __index so it reflects the attribute value at callback
	-- time rather than at setup time — the tag may replicate before the attribute does.
	local function buildContext(model: Model): any
		local base = {
			Model = nil, -- stamped by AnimateCombatNPCModule.setup()
			SoundEngine = getSoundEngine(),
			VFXService = VFXController:GetVFXEngine(),
			CombatService = CombatService,
		}
		return setmetatable(base, {
			__index = function(_, key)
				if key == "NPCId" then
					return model:GetAttribute("NPCId")
				end
				return nil
			end,
		})
	end

	-- CollectionService listener for combat NPC models
	local function onTagAdded(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		local model = instance :: Model

		-- Register model in event dispatcher for server event routing
		local npcId = model:GetAttribute("NPCId") :: string?
		if npcId then
			self._EventDispatcher:RegisterModel(npcId, model)

			-- Mount billboard — HP is read live from the Humanoid
			local displayName = model:GetAttribute("DisplayName") :: string? or model.Name
			self._BillboardService:Mount(npcId, model, displayName)
		end

		local context = buildContext(model)
		AnimateCombatNPCModule.setup(model, context):andThen(function(cleanup)
			if cleanup then
				self._ActiveCleanups[model] = cleanup
			end
		end)
	end

	local function onTagRemoved(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		local model = instance :: Model

		-- Unregister from event dispatcher and unmount billboard
		local npcId = model:GetAttribute("NPCId") :: string?
		if npcId then
			self._EventDispatcher:UnregisterModel(npcId)
			self._BillboardService:Unmount(npcId)
		end

		local cleanup = self._ActiveCleanups[model]
		if cleanup then
			cleanup()
			self._ActiveCleanups[model] = nil
		end
	end

	-- Handle already-tagged instances
	for _, instance in CollectionService:GetTagged(TAG) do
		task.spawn(onTagAdded, instance)
	end

	-- Handle future tagged instances
	CollectionService:GetInstanceAddedSignal(TAG):Connect(onTagAdded)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(onTagRemoved)

	print("[CombatNPCController] Started")
end

--[[
    Get the event dispatcher for registering custom event handlers.
    Used by NPCCommandController to deselect dead NPCs.
]]
function CombatNPCController:GetEventDispatcher(): any
	return self._EventDispatcher
end

return CombatNPCController
