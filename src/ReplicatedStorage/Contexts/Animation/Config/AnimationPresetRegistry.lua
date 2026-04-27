--!strict

local PlayerPreset = require(script.Parent.Presets.Player)
local WorkerPreset = require(script.Parent.Presets.Worker)
local CombatNPCPreset = require(script.Parent.Presets.CombatNPC)
local EnemyLocomotionPreset = require(script.Parent.Presets.EnemyLocomotion)
local StructurePreset = require(script.Parent.Presets.Structure)
local Types = require(script.Parent.Parent.Types.AnimationTypes)

type TPresetId = Types.TPresetId
type TAnimationPreset = Types.TAnimationPreset

local PRESETS: { [TPresetId]: TAnimationPreset } = {
	Player = PlayerPreset,
	Worker = WorkerPreset,
	CombatNPC = CombatNPCPreset,
	EnemyLocomotion = EnemyLocomotionPreset,
	Structure = StructurePreset,
}

local AnimationPresetRegistry = {}

function AnimationPresetRegistry.Get(presetId: TPresetId): TAnimationPreset
	local preset = PRESETS[presetId]
	assert(preset ~= nil, ("AnimationPresetRegistry: unknown preset '%s'"):format(tostring(presetId)))
	return preset
end

function AnimationPresetRegistry.Exists(presetId: string): boolean
	return PRESETS[presetId :: TPresetId] ~= nil
end

return table.freeze(AnimationPresetRegistry)
