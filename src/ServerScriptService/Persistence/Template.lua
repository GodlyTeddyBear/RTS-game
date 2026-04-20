--!strict

--[=[
	@class Template
	Defines the default data schema for a new player profile.
	@server
]=]

--[=[
	@interface Template
	@within Template
	.SchemaVersion number -- Schema version for future data migrations
	.Metadata {} -- Reserved metadata for ID generation and tracking
	.Inventory { Slots: {}, Metadata: { TotalSlots: number, UsedSlots: number, LastModified: number } } -- Shared party inventory pool
	.Equipment {} -- Per-character equipment map keyed by characterId
	.Flags {} -- Player flags for NPC dialogue conditions and game state
	.Settings {} -- Player settings and preferences
	.Gold number -- Starting gold amount
	.Guild { Adventurers: {} } -- Guild roster of adventurers
	.Commission { Board: {}, Active: {}, Tokens: number, CurrentTier: number, LastRefreshTime: number } -- Commission board state
	.Quest { CompletedCount: number } -- Quest and expedition tracking
	.Task { Tasks: {} } -- Non-expedition player task progress
	.Unlocks {} -- Set of explicitly unlocked content IDs
	.Upgrade { Levels: {} } -- Player-purchased upgrade levels keyed by upgrade id
	.Production { Upgrades: {}, Prestige: {}, Workers: {}, Buildings: {}, Metadata: {} } -- Production system state
]=]

return {
	-- Schema version for future migrations
	SchemaVersion = 1,

	-- Metadata for ID generation and tracking
	Metadata = {},

	-- Shared party inventory: All characters access same pool of items
	Inventory = {
		Slots = {}, -- Sparse array [slotIndex] = { ItemId, Quantity, SlotIndex }
		Metadata = {
			TotalSlots = 200,
			UsedSlots = 0,
			LastModified = 0,
		},
	},

	-- Equipment per character: [characterId] = { [slotType] = { ItemId, SlotType } }
	Equipment = {},

	-- Player flags for NPC dialogue conditions and game state
	-- { [flagName]: boolean | string | number }
	Flags = {},

	-- Player settings and preferences
	Settings = {
		Sound = {
			MasterVolume = 1,
			MusicVolume = 0.8,
			SfxVolume = 1,
			UiVolume = 1,
			AmbientVolume = 0.6,
			Enabled = true,
		},
	},

	-- Currency
	Gold = 1000,

	-- Guild: adventurer roster
	Guild = {
		Adventurers = {}, -- [adventurerId: string] = TAdventurer data
	},

	-- Commission system: board, active commissions, tokens, tier
	Commission = {
		Board = {}, -- { TBoardCommission }
		Active = {}, -- { TActiveCommission }
		Tokens = 0,
		CurrentTier = 1,
		LastRefreshTime = 0,
	},

	-- Quest system: expedition tracking
	Quest = {
		CompletedCount = 0,
		-- Note: ActiveExpedition is NOT persisted.
		-- Live expedition state is in-memory only and is not restored on server restart.
	},

	-- Task system: generic non-expedition task progress
	Task = {
		Tasks = {},
	},

	-- Unlock system: tracks which content the player has unlocked
	-- Only stores explicitly unlocked items. Absence means locked (or StartsUnlocked in config).
	-- { [targetId: string]: true }
	Unlocks = {},

	-- Chapter progression: current chapter number, starts at 1
	Chapter = 1,

	-- Player-purchased upgrade system: flat leveled list
	-- Levels: { [upgradeId: string]: number } (absent means level 0)
	Upgrade = {
		Levels = {},
	},

	-- Production system: resources, upgrades, prestige
	Production = {
		Upgrades = {
			ClickMultiplier = { Wood = 0, Stone = 0, Ore = 0 },
			AutoHarvesters = { Wood = 0, Stone = 0, Ore = 0 },
			Efficiency = { Wood = 0, Stone = 0, Ore = 0 },
			CraftingStations = { Planks = 0, Bricks = 0, Ingots = 0 },
			WorkshopLevel = 0,
		},
		Prestige = {
			Level = 0,
			LifetimeGoldEarned = 0,
		},
		Workers = {
			-- [workerId] = { Id, Type, Level, Experience, AssignedTo, LastProductionTick }
		},
		Buildings = {
			-- [zoneName] = { [slotIndex] = { BuildingType: string, Level: number } }
		},
		-- [slotKey] = machine state — slotKey = "ZoneName:slotIndex"
		MachineRuntime = {},
		Metadata = {
			LastTick = 0,
			LastSave = 0,
		},
	},
}
