--!strict

--[[
	Default unlock metadata for items sold in the shop.
	See `.claude/documents/architecture/UNLOCK_REGISTRY.md`.
]]

local ItemData = require(script.Parent.Parent.Types.ItemData)

local CHAPTER_FUTURE = 99

local TIER_PRESETS: { [string]: ItemData.ItemUnlockMetadata } = table.freeze({
	Chapter1Basic = {
		Category = "ShopItem",
		Conditions = {},
		AutoUnlock = true,
		StartsUnlocked = true,
	},
	Chapter2IronGear = {
		Category = "ShopItem",
		Conditions = { Chapter = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},
	Chapter3StarterPotion = {
		Category = "ShopItem",
		Conditions = { Chapter = 3 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},
	FutureLocked = {
		Category = "ShopItem",
		Conditions = { Chapter = CHAPTER_FUTURE },
		AutoUnlock = true,
		StartsUnlocked = false,
	},
})

local function _copyPreset(name: string): ItemData.ItemUnlockMetadata
	local preset = TIER_PRESETS[name]
	return {
		Category = preset.Category,
		Conditions = table.clone(preset.Conditions),
		AutoUnlock = preset.AutoUnlock,
		StartsUnlocked = preset.StartsUnlocked,
	}
end

local function chapter1BasicShopItemUnlock(): ItemData.ItemUnlockMetadata
	return _copyPreset("Chapter1Basic")
end

local function chapter2IronGearUnlock(): ItemData.ItemUnlockMetadata
	return _copyPreset("Chapter2IronGear")
end

local function chapter3StarterPotionUnlock(): ItemData.ItemUnlockMetadata
	return _copyPreset("Chapter3StarterPotion")
end

local function futureLockedUnlock(): ItemData.ItemUnlockMetadata
	return _copyPreset("FutureLocked")
end

return {
	CHAPTER_FUTURE = CHAPTER_FUTURE,
	chapter1BasicShopItemUnlock = chapter1BasicShopItemUnlock,
	chapter2IronGearUnlock = chapter2IronGearUnlock,
	chapter3StarterPotionUnlock = chapter3StarterPotionUnlock,
	futureLockedUnlock = futureLockedUnlock,
}
