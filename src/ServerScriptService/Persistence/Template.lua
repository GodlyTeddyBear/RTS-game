--!strict

--[=[
	@class Template
	Defines the default RTS profile schema for a new player profile.
	@server
]=]

--[=[
	@interface Template
	@within Template
	.SchemaVersion number -- Schema version for future migrations
	.Settings { Sound: { MasterVolume: number, MusicVolume: number, SfxVolume: number, UiVolume: number, AmbientVolume: number, Enabled: boolean } } -- Player settings and preferences
	.RunStats { TotalRuns: number, BestWave: number, TotalWavesCleared: number } -- Cross-run RTS progression stats
	.Unlocks { [string]: true } -- Set of explicitly unlocked RTS content ids
]=]

return {
	-- Schema version for future migrations.
	SchemaVersion = 2,

	-- Player settings and preferences.
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

	-- RTS meta progression stats (inter-run persistence).
	RunStats = {
		TotalRuns = 0,
		BestWave = 0,
		TotalWavesCleared = 0,
	},

	-- Flat unlocked content set: [targetId] = true
	Unlocks = {},
}
