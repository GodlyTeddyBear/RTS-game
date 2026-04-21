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
		key = "Mobility",
		displayName = "Blink Step",
		energyCost = 15,
		cooldownDuration = 10,
		metadata = {
			maxRange = 18,
		},
	},
	{
		key = "SummonA",
		displayName = "Swarm Drones",
		energyCost = 20,
		cooldownDuration = 18,
		metadata = {
			summonCount = 5,
			lifetime = 20,
		},
	},
	{
		key = "SummonB",
		displayName = "Elite Guardian",
		energyCost = 45,
		cooldownDuration = 25,
		metadata = {
			lifetime = 30,
			stationary = true,
		},
	},
	{
		key = "Control",
		displayName = "Gravity Pulse",
		energyCost = 25,
		cooldownDuration = 14,
		metadata = {
			radius = 10,
			knockbackStuds = 8,
			slowDuration = 1.5,
		},
	},
	{
		key = "Ultimate",
		displayName = "Overcharge Field",
		energyCost = 70,
		cooldownDuration = 55,
		metadata = {
			channelTime = 1,
			interruptibleByDamage = true,
			radius = 25,
			stunDuration = 3,
			structureAttackSpeedMultiplier = 1.5,
			buffDuration = 8,
		},
	},
} :: { AbilitySlotDef }

for _, slot in CommanderConfig.SLOTS do
	if slot.metadata then
		table.freeze(slot.metadata)
	end
	table.freeze(slot)
end

table.freeze(CommanderConfig.SLOTS)

return table.freeze(CommanderConfig)
