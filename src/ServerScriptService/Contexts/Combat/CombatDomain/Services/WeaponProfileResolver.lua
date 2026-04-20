--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponCategoryConfig = require(ReplicatedStorage.Contexts.Combat.Config.WeaponCategoryConfig)

type TWeaponProfile = WeaponCategoryConfig.TWeaponProfile

--[=[
	@class WeaponProfileResolver
	Domain service that resolves weapon category strings to attack profiles.

	Pure function with no side effects: looks up the weapon category in
	`WeaponCategoryConfig` and returns the matching profile. Falls back to
	`Punch` for unknown categories.
	@server
]=]
local WeaponProfileResolver = {}
WeaponProfileResolver.__index = WeaponProfileResolver

export type TWeaponProfileResolver = typeof(setmetatable({}, WeaponProfileResolver))

function WeaponProfileResolver.new(): TWeaponProfileResolver
	return setmetatable({}, WeaponProfileResolver)
end

--[=[
	Resolve a weapon category to its attack profile.

	Returns the profile from `WeaponCategoryConfig` for the given category,
	or falls back to `Punch` if the category is nil or unknown.
	@within WeaponProfileResolver
	@param weaponCategory string? -- Weapon category name (e.g., "Sword", "Staff")
	@return TWeaponProfile -- The matching weapon profile
]=]
function WeaponProfileResolver:Resolve(weaponCategory: string?): TWeaponProfile
	if weaponCategory and WeaponCategoryConfig[weaponCategory] then
		return WeaponCategoryConfig[weaponCategory]
	end
	return WeaponCategoryConfig.Punch
end

return WeaponProfileResolver
