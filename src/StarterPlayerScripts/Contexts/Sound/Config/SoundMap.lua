--!strict

--[[
	SoundMap - Maps event names and sound keys to playback instructions.

	Used by SoundController to determine what sound to play when a GameEvent
	fires or when the server sends a PlaySound signal.

	Structure:
		[key] = { SoundId, Category, Volume?, Cooldown?, PlaybackSpeed? }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundIds = require(ReplicatedStorage.Contexts.Sound.Config.SoundIds)

return table.freeze({
	-- Server-triggered sounds (received via Knit PlaySound signal with soundKey)
	MiningComplete = table.freeze({
		SoundId = SoundIds.SFX.MiningComplete,
		Category = "SFX",
	}),
	LevelUp = table.freeze({
		SoundId = SoundIds.SFX.LevelUp,
		Category = "SFX",
		Volume = 0.8,
	}),
	WorkerHired = table.freeze({
		SoundId = SoundIds.SFX.WorkerHired,
		Category = "SFX",
	}),
	Purchase = table.freeze({
		SoundId = SoundIds.SFX.Purchase,
		Category = "SFX",
	}),
	PurchaseFailed = table.freeze({
		SoundId = SoundIds.UI.Error,
		Category = "UI",
	}),
	Sell = table.freeze({
		SoundId = SoundIds.SFX.Sell,
		Category = "SFX",
	}),
	CraftStart = table.freeze({
		SoundId = SoundIds.SFX.CraftStart,
		Category = "SFX",
	}),
	CraftComplete = table.freeze({
		SoundId = SoundIds.SFX.CraftComplete,
		Category = "SFX",
	}),
	ItemPickup = table.freeze({
		SoundId = SoundIds.SFX.ItemPickup,
		Category = "SFX",
		Cooldown = 0.15,
	}),
	CommissionAccepted = table.freeze({
		SoundId = SoundIds.SFX.CommissionAccepted,
		Category = "SFX",
	}),
	CommissionDelivered = table.freeze({
		SoundId = SoundIds.SFX.CommissionDelivered,
		Category = "SFX",
	}),
	TierUnlocked = table.freeze({
		SoundId = SoundIds.SFX.TierUnlocked,
		Category = "SFX",
		Volume = 0.9,
	}),
	Equip = table.freeze({
		SoundId = SoundIds.SFX.Equip,
		Category = "SFX",
	}),

	-- Client-triggered sounds (from GameEvents signals)
	ItemBought = table.freeze({
		SoundId = SoundIds.SFX.Purchase,
		Category = "SFX",
	}),
	ItemSoldClient = table.freeze({
		SoundId = SoundIds.SFX.Sell,
		Category = "SFX",
	}),
	CommissionAcceptedClient = table.freeze({
		SoundId = SoundIds.SFX.CommissionAccepted,
		Category = "SFX",
	}),
	CommissionDeliveredClient = table.freeze({
		SoundId = SoundIds.SFX.CommissionDelivered,
		Category = "SFX",
	}),
	ButtonClicked = table.freeze({
		SoundId = SoundIds.UI.ButtonClick,
		Category = "UI",
		Cooldown = 0.05,
	}),
	MenuOpened = table.freeze({
		SoundId = SoundIds.UI.MenuOpen,
		Category = "UI",
	}),
	MenuClosed = table.freeze({
		SoundId = SoundIds.UI.MenuClose,
		Category = "UI",
	}),
	TabSwitched = table.freeze({
		SoundId = SoundIds.UI.TabSwitch,
		Category = "UI",
		Cooldown = 0.1,
	}),
	ErrorOccurred = table.freeze({
		SoundId = SoundIds.UI.Error,
		Category = "UI",
	}),
})
