--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)
local TaskTypes = require(ReplicatedStorage.Contexts.Task.Types.TaskTypes)

type TTaskDefinition = TaskTypes.TTaskDefinition

local config: { [string]: TTaskDefinition } = {
	FirstCharcoal = {
		Id = "FirstCharcoal",
		Title = "Light the Forge",
		Description = "Craft charcoal for the first workshop orders.",
		UnlockConditions = {
			Chapter = 1,
		},
		Objectives = {
			{
				Id = "CraftCharcoal",
				Kind = "CraftItem",
				TargetId = ItemId.Charcoal,
				Required = 1,
				Description = "Craft 1 Charcoal",
			},
		},
		Rewards = {
			Gold = 50,
			Items = {
				{ ItemId = ItemId.Wood, Quantity = 5 },
			},
			Flags = {
				Task_FirstCharcoalClaimed = true,
			},
		},
	},

	FirstGoblinHunt = {
		Id = "FirstGoblinHunt",
		Title = "Goblin Trouble",
		Description = "Clear out goblins threatening the trade path.",
		UnlockConditions = {
			Chapter = 1,
			CompletedTaskIds = { "FirstCharcoal" },
		},
		Objectives = {
			{
				Id = "KillGoblins",
				Kind = "KillNPC",
				TargetId = "Goblin",
				Required = 3,
				Description = "Defeat 3 Goblins",
			},
		},
		Rewards = {
			Gold = 100,
			Items = {
				{ ItemId = ItemId.HealingPotion, Quantity = 1 },
			},
			Flags = {
				Task_FirstGoblinHuntClaimed = true,
			},
		},
	},
}

return table.freeze(config)
