--!strict

--[[
	VFXConfig - Centralized VFX configuration.

	Maps effect keys to their settings. All contexts reference this single config
	to resolve effect categories, lifetimes, and attachment offsets.

	Categories determine which EffectRegistry subfolder to look up:
		"Skill"        -> Effects/Skills/
		"StatusEffect" -> Effects/StatusEffects/

	Usage:
		local VFXConfig = require(ReplicatedStorage.Contexts.VFX.Config.VFXConfig)
		local config = VFXConfig.Effects.MiningDust
		-- config.Category == "Skill"
		-- config.DefaultLifetime == 2
]]

export type TVFXEffectConfig = {
	Category: "Skill" | "StatusEffect",
	DefaultLifetime: number?,
	AttachOffset: CFrame?,
}

export type TVFXOptions = {
	Position: Vector3?,
	TargetInstance: Instance?,
	AttachTo: string?,
	Offset: CFrame?,
}

return table.freeze({
	Effects = table.freeze({
		-- Combat effects
		MiningDust = table.freeze({
			Category = "Skill" :: "Skill" | "StatusEffect",
			DefaultLifetime = nil :: number?,
			AttachOffset = nil :: CFrame?,
		}),
	}),
})
