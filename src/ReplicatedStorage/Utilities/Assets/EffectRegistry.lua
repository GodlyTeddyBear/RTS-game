--!strict

--[[
	EffectRegistry - Load Visual Effects for Skills and Status Effects

	Provides a registry for loading visual effects (ParticleEmitters, Beams, etc.)
	for skills and status effects.

	Folder Structure:
		Effects/
		├── Skills/
		│   ├── Slash/
		│   │   └── [ParticleEmitters, Beams, Models, etc.]
		│   ├── Fireball/
		│   │   └── [Visual effects]
		│   └── HealingLight/
		│       └── [Visual effects]
		└── StatusEffects/
		    ├── Burn/
		    │   └── [Particle effects]
		    ├── Poison/
		    │   └── [Particle effects]
		    └── Stun/
		        └── [Visual indicators]

	Usage:
		local effectRegistry = EffectRegistry.new(Assets.Effects)
		local slashEffect = effectRegistry:GetSkillEffect("Slash")
		local burnEffect = effectRegistry:GetStatusEffect("Burn")
]]

local EffectRegistry = {}
EffectRegistry.__index = EffectRegistry

--[=[
	Creates a new EffectRegistry.

	@param effectsFolder Folder - The root Effects folder
	@return EffectRegistry - New registry instance
]=]
function EffectRegistry.new(effectsFolder: Folder)
	assert(effectsFolder, "EffectRegistry requires a valid Effects folder")
	assert(effectsFolder:IsA("Folder"), "EffectRegistry requires a Folder instance")

	local self = setmetatable({}, EffectRegistry)
	self._skillsFolder = effectsFolder:FindFirstChild("Skills")
	self._statusEffectsFolder = effectsFolder:FindFirstChild("StatusEffects")

	return self
end

--[=[
	Gets a visual effect for a skill.

	@param skillName string - The skill name (e.g., "Slash", "Fireball")
	@return Folder | Model - Cloned effect container

	Example:
		local slashEffect = registry:GetSkillEffect("Slash")
		slashEffect.Parent = workspace
]=]
function EffectRegistry:GetSkillEffect(skillName: string): Folder | Model
	assert(self._skillsFolder, "Skills folder not found in Effects")

	local effectFolder = self._skillsFolder:FindFirstChild(skillName)
	assert(effectFolder, "Skill effect not found: " .. skillName)

	return effectFolder:Clone()
end

--[=[
	Gets a visual effect for a status effect.

	@param effectType string - The status effect type (e.g., "Burn", "Poison")
	@return Folder | Model - Cloned effect container

	Example:
		local burnEffect = registry:GetStatusEffect("Burn")
		burnEffect.Parent = character
]=]
function EffectRegistry:GetStatusEffect(effectType: string): Folder | Model
	assert(self._statusEffectsFolder, "StatusEffects folder not found in Effects")

	local effectFolder = self._statusEffectsFolder:FindFirstChild(effectType)
	assert(effectFolder, "Status effect not found: " .. effectType)

	return effectFolder:Clone()
end

--[=[
	Checks if a skill effect exists.

	@param skillName string - The skill name
	@return boolean - True if effect exists

	Example:
		if registry:SkillEffectExists("Slash") then
			local effect = registry:GetSkillEffect("Slash")
		end
]=]
function EffectRegistry:SkillEffectExists(skillName: string): boolean
	if not self._skillsFolder then
		return false
	end

	return self._skillsFolder:FindFirstChild(skillName) ~= nil
end

--[=[
	Checks if a status effect exists.

	@param effectType string - The status effect type
	@return boolean - True if effect exists

	Example:
		if registry:StatusEffectExists("Burn") then
			local effect = registry:GetStatusEffect("Burn")
		end
]=]
function EffectRegistry:StatusEffectExists(effectType: string): boolean
	if not self._statusEffectsFolder then
		return false
	end

	return self._statusEffectsFolder:FindFirstChild(effectType) ~= nil
end

return EffectRegistry
