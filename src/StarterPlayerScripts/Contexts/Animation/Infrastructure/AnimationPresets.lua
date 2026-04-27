--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationPresetRegistry = require(ReplicatedStorage.Contexts.Animation.Config.AnimationPresetRegistry)

local AnimationPresets = {}

local function _ClonePreset(preset: any): any
	local clone = {}
	for key, value in preset do
		clone[key] = value
	end
	return clone
end

function AnimationPresets.Player(animationsFolder: Folder)
	local preset = _ClonePreset(AnimationPresetRegistry.Get("Player"))
	preset.AnimationsFolder = animationsFolder
	preset.UseDirectAnimationsFolder = true
	return table.freeze(preset)
end

AnimationPresets.Worker = AnimationPresetRegistry.Get("Worker")
AnimationPresets.CombatNPC = AnimationPresetRegistry.Get("CombatNPC")
AnimationPresets.EnemyLocomotion = AnimationPresetRegistry.Get("EnemyLocomotion")
AnimationPresets.Structure = AnimationPresetRegistry.Get("Structure")

return AnimationPresets
