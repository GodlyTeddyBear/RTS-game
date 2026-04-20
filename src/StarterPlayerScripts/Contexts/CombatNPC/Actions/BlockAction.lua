--!strict

--[[
    BlockAction - Action class for the "Blocking" animation state on combat NPCs.

    Extends BaseAction via metatable inheritance.

    Plays the block-hold animation (looped) while the entity has CombatState = "Blocking".
    No keyframe markers needed for the basic block — add entries to Events if SFX/VFX
    on specific block animation frames are required later.

    Context shape (TActionContext, injected by CombatNPCController via AnimateCombatNPCModule):
        {
            Model:         Model,
            SoundEngine:   SoundEngine,
            VFXService:    VFXEngine,
            CombatService: KnitService,
            NPCId:         string,
        }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseAction = require(ReplicatedStorage.Utilities.ActionSystem.BaseAction)

local BlockAction = {}
BlockAction.__index = BlockAction
setmetatable(BlockAction, BaseAction)

BlockAction.AnimationKey = "Blocking"
BlockAction.Looped = true

BlockAction.Events = {}

function BlockAction.new()
	local self = BaseAction.new()
	return setmetatable(self :: any, BlockAction)
end

return BlockAction
