--!strict

--[[
    AttackAction - Action class for the "Attack" animation state on combat NPCs.

    Extends BaseAction via metatable inheritance. The Events table drives
    data-driven SFX/VFX dispatching and server callbacks.

    The "Strike" keyframe marker on attack animations triggers:
    - ServerCallback "ActivateHitbox" → tells server to spawn the hitbox at this frame
    - (Optional) SFX/VFX for the swing itself

    Add keyframe markers named "Strike" to attack animation assets in Roblox Studio.

    Context shape (TActionContext, injected by CombatNPCController via AnimateCombatNPCModule):
        {
            Model:         Model,
            SoundEngine:   SoundEngine,   -- from SoundController
            VFXService:    VFXEngine,     -- from VFXController
            CombatService: KnitService,   -- CombatContext client proxy
            NPCId:         string,        -- NPC identifier for server callbacks
        }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseAction = require(ReplicatedStorage.Utilities.ActionSystem.BaseAction)

local AttackAction = {}
AttackAction.__index = AttackAction
setmetatable(AttackAction, BaseAction)

AttackAction.AnimationKey = "Attack"
AttackAction.Looped = false

AttackAction.Events = {
	Strike = { ServerCallback = "ActivateHitbox" },
}

function AttackAction.new()
	local self = BaseAction.new()
	return setmetatable(self :: any, AttackAction)
end

function AttackAction:OnCustomEvent()
	--print("There was an attack action")
end

return AttackAction
