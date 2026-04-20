--!strict
export type BreweryRecipeId =
	-- Basic Potions
	"HealingBrew"
	| "ManaBrew"
	| "AntidoteBrew"
	-- Tonics
	| "StrengthTonic"
	| "DefenseTonic"
	| "SpeedTonic"
	| "LuckElixir"
	-- Greater Potions
	| "GreaterHealingBrew"
	| "GreaterManaBrew"
	-- Elixirs
	| "VitalityElixir"
	| "FortitudeElixir"
	| "SwiftnessElixir"
	| "OracleElixir"
	| "PhoenixElixir"

return {
	-- Basic Potions
	HealingBrew = "HealingBrew" :: "HealingBrew",
	ManaBrew = "ManaBrew" :: "ManaBrew",
	AntidoteBrew = "AntidoteBrew" :: "AntidoteBrew",
	-- Tonics
	StrengthTonic = "StrengthTonic" :: "StrengthTonic",
	DefenseTonic = "DefenseTonic" :: "DefenseTonic",
	SpeedTonic = "SpeedTonic" :: "SpeedTonic",
	LuckElixir = "LuckElixir" :: "LuckElixir",
	-- Greater Potions
	GreaterHealingBrew = "GreaterHealingBrew" :: "GreaterHealingBrew",
	GreaterManaBrew = "GreaterManaBrew" :: "GreaterManaBrew",
	-- Elixirs
	VitalityElixir = "VitalityElixir" :: "VitalityElixir",
	FortitudeElixir = "FortitudeElixir" :: "FortitudeElixir",
	SwiftnessElixir = "SwiftnessElixir" :: "SwiftnessElixir",
	OracleElixir = "OracleElixir" :: "OracleElixir",
	PhoenixElixir = "PhoenixElixir" :: "PhoenixElixir",
}
