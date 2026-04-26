--!strict

--[[
	SoundIds - Centralized sound asset ID constants.

	All sound asset IDs are defined here. Replace placeholder values with
	real rbxassetid:// values when sounds are sourced.
]]

return table.freeze({
	UI = table.freeze({
		ButtonClick = "rbxassetid://121348992695732",
		MenuOpen = "rbxassetid://124090638128523",
		MenuClose = "rbxassetid://99986846550938",
		TabSwitch = "rbxassetid://121348992695732",
		Error = "rbxassetid://102587330979671",
		Success = "rbxassetid://78813992373956",
	}),
	SFX = table.freeze({
		-- Phase 2 gameplay cues. Reuse existing IDs until bespoke assets are sourced.
		EnemySpawn = "rbxassetid://122491880786027",
		EnemyHit = "rbxassetid://140462043853173",
		EnemyDeath = "rbxassetid://136398605613669",
		BaseHit = "rbxassetid://113295635662652",
		BaseDestroyed = "rbxassetid://99283032437257",
		PlacementSuccess = "rbxassetid://136993031050456",
		PlacementInvalid = "rbxassetid://134722801683376",
		WaveStart = "rbxassetid://137884319678560",
		WaveClear = "rbxassetid://117806862877011",
		AbilityUse = "rbxassetid://95235663185086",
		CommanderAbilityUse = "rbxassetid://95235663185086",
		ChoppingHit = "rbxassetid://9113226115",
		MiningHit = "rbxassetid://9116676206",
		MiningComplete = "rbxassetid://117793859307433",
		ItemPickup = "rbxassetid://134602992766192",
		Purchase = "rbxassetid://17161225362",
		Sell = "rbxassetid://107443561096401",
		CraftStart = "rbxassetid://136018091472555",
		CraftComplete = "rbxassetid://121008865478431",
		LevelUp = "rbxassetid://6932058301",
		WorkerHired = "rbxassetid://138934842574924",
		CommissionAccepted = "rbxassetid://135556326413313",
		CommissionDelivered = "rbxassetid://100288208393628",
		TierUnlocked = "rbxassetid://113307491257691",
		Equip = "rbxassetid://127619339252879",
	}),
	Music = table.freeze({
		MainTheme = "rbxassetid://73309900739464",
	}),
	Ambient = table.freeze({
		MiningLoop = "rbxassetid://0",
	}),
})
