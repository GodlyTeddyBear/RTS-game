--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type AbilitySlotDef = CommanderTypes.AbilitySlotDef

--[=[
	@class CommanderConfig
	Defines the shared commander tuning values used by server and client code.
	@server
	@client
]=]
local CommanderConfig = {}

--[=[
	@prop MAX_HP number
	@within CommanderConfig
	The maximum HP assigned to each commander.
]=]
CommanderConfig.MAX_HP = 100

--[=[
	@prop SLOTS { AbilitySlotDef }
	@within CommanderConfig
	The canonical commander ability kit used by the command and UI layers.
]=]
CommanderConfig.SLOTS = {
	{
		Key = "Mobility",
		DisplayName = "Blink Step",
		EnergyCost = 15,
		CooldownDuration = 10,
		Metadata = {
			MaxRange = 18,
			LockedWhileOverchargeChanneling = true,
		},
	},
	{
		Key = "SummonA",
		DisplayName = "Swarm Drones",
		EnergyCost = 5,
		CooldownDuration = 18,
		Metadata = {
			SummonCount = 5,
			Lifetime = 20,
			TargetingRule = "NearestEnemy",
		},
	},
	{
		Key = "SummonB",
		DisplayName = "Elite Guardian",
		EnergyCost = 45,
		CooldownDuration = 25,
		Metadata = {
			Lifetime = 30,
			Stationary = true,
			PathingMode = "PassThrough",
		},
	},
	{
		Key = "Control",
		DisplayName = "Gravity Pulse",
		EnergyCost = 25,
		CooldownDuration = 14,
		Metadata = {
			Radius = 10,
			KnockbackStuds = 8,
			SlowDuration = 1.5,
		},
	},
	{
		Key = "Ultimate",
		DisplayName = "Overcharge Field",
		EnergyCost = 70,
		CooldownDuration = 55,
		Metadata = {
			ChannelTime = 1,
			InterruptibleByDamage = true,
			MovementLockedDuringChannel = true,
			Radius = 25,
			StunDuration = 3,
			StructureAttackSpeedMultiplier = 1.5,
			BuffDuration = 8,
		},
	},
} :: { AbilitySlotDef }

for _, slot in CommanderConfig.SLOTS do
	if slot.Metadata then
		table.freeze(slot.Metadata)
	end
	table.freeze(slot)
end

table.freeze(CommanderConfig.SLOTS)

return table.freeze(CommanderConfig)
