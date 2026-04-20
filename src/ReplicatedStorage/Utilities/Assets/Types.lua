--!strict

--[[
	Types - Shared Type Definitions for Asset Registries

	Defines type structures used across all asset registries for type safety and documentation.
]]

--[=[
	Animation asset metadata

	@interface TAnimationAsset
	@field Animation Animation - The animation instance
	@field ActionType string - The action type path (e.g., "Skills/Slash", "BasicAttack")
	@field Class string? - Optional class name (e.g., "Warrior", "Mage")
]=]
export type TAnimationAsset = {
	Animation: Animation,
	ActionType: string,
	Class: string?,
}

--[=[
	Entity model asset metadata

	@interface TEntityAsset
	@field Model Model - The entity model (cloned)
	@field EntityType "Player" | "Enemy" - Whether this is a player or enemy entity
	@field Name string - The entity name (class name or enemy name)
]=]
export type TEntityAsset = {
	Model: Model,
	EntityType: "Player" | "Enemy",
	Name: string,
}

--[=[
	Visual effect asset metadata

	@interface TEffectAsset
	@field Effect Folder | Model - The effect container (ParticleEmitters, Beams, etc.)
	@field EffectType "Skill" | "StatusEffect" - Category of effect
	@field Name string - The effect name (e.g., "Slash", "Burn")
]=]
export type TEffectAsset = {
	Effect: Folder | Model,
	EffectType: "Skill" | "StatusEffect",
	Name: string,
}

--[=[
	Sound effect asset metadata

	@interface TSoundAsset
	@field Sound Sound - The sound instance
	@field SoundType "Combat" | "UI" - Category of sound
	@field Name string - The sound name (e.g., "BasicAttack", "ButtonClick")
]=]
export type TSoundAsset = {
	Sound: Sound,
	SoundType: "Combat" | "UI",
	Name: string,
}

return {}
