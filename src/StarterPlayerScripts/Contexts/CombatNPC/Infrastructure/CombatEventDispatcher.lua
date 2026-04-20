--!strict

--[[
    CombatEventDispatcher - Client-side dispatcher for server-sourced NPC events.

    Receives batches of TNPCEvent from the CombatContext.Client.NPCEvent signal,
    routes each event to the correct NPC model via a model registry, and dispatches
    effects using a hybrid approach:
      1. Data-driven: CombatEffectsConfig maps EventType → { SFX, VFX }
      2. Code-driven: Registered handler functions for complex logic (damage numbers,
         screen shake, etc.)

    The dispatcher does NOT handle animation-timed effects — those continue through
    the existing ActionEventRouter / BaseAction marker system.

    Usage:
        local dispatcher = CombatEventDispatcher.new(soundEngine, vfxService)
        dispatcher:RegisterModel(npcId, model)
        dispatcher:Dispatch(eventBatch)  -- called from Knit signal handler
        dispatcher:UnregisterModel(npcId)

    Custom handlers:
        dispatcher:OnEvent("Damaged", function(event, model)
            -- spawn damage number, screen shake, etc.
        end)
]]

local CombatEffectsConfig = require(script.Parent.Parent.Config.CombatEffectsConfig)

local CombatEventDispatcher = {}
CombatEventDispatcher.__index = CombatEventDispatcher

export type TCombatEventDispatcher = typeof(setmetatable({} :: {
	_SoundEngine: any,
	_VFXService: any,
	_ModelRegistry: { [string]: Model },
	_CustomHandlers: { [string]: (any, Model) -> () },
}, CombatEventDispatcher))

function CombatEventDispatcher.new(): TCombatEventDispatcher
	local self = setmetatable({}, CombatEventDispatcher)
	self._SoundEngine = nil :: any
	self._VFXService = nil :: any
	self._ModelRegistry = {}
	self._CustomHandlers = {}
	return self
end

function CombatEventDispatcher:Start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Knit = require(ReplicatedStorage.Packages.Knit)
	local SoundController = Knit.GetController("SoundController")
	local VFXController = Knit.GetController("VFXController")
	self._SoundEngine = SoundController
	self._VFXService = VFXController and VFXController:GetVFXEngine()
end

--[[
    Register an NPC model so events targeting this NPCId are routed to it.
]]
function CombatEventDispatcher:RegisterModel(npcId: string, model: Model)
	self._ModelRegistry[npcId] = model
end

--[[
    Unregister an NPC model (e.g., on tag removal or model destroyed).
]]
function CombatEventDispatcher:UnregisterModel(npcId: string)
	self._ModelRegistry[npcId] = nil
end

--[[
    Register a custom handler for a specific event type.
    Called after data-driven effects are dispatched.
]]
function CombatEventDispatcher:OnEvent(eventType: string, handler: (any, Model) -> ())
	self._CustomHandlers[eventType] = handler
end

--[[
    Dispatch a batch of TNPCEvent from the server.
    For each event:
      1. Resolve the target model from the registry
      2. Apply data-driven SFX/VFX from CombatEffectsConfig
      3. Call the custom handler if one is registered for this EventType
]]
function CombatEventDispatcher:Dispatch(events: { any })
	for _, event in events do
		local npcId = event.TargetNPCId
		if not npcId then
			continue
		end

		local model = self._ModelRegistry[npcId]
		if not model or not model.Parent then
			continue
		end

		-- Data-driven effects from config
		local effectDef = CombatEffectsConfig[event.EventType]
		if effectDef then
			local sfxKey = event.SoundKey or effectDef.SFX
			if sfxKey and self._SoundEngine then
				self._SoundEngine:PlaySFX(sfxKey)
			end

			local vfxKey = event.EffectKey or effectDef.VFX
			if vfxKey and self._VFXService then
				local position = event.Position
				if not position and model.PrimaryPart then
					position = model.PrimaryPart.Position
				end
				if position then
					self._VFXService:Spawn(vfxKey, position)
				end
			end
		end

		-- Custom handler for complex logic
		local handler = self._CustomHandlers[event.EventType]
		if handler then
			handler(event, model)
		end
	end
end

return CombatEventDispatcher
