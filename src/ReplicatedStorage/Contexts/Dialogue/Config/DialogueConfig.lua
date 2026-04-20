--!strict

return table.freeze({
	-- NPCs listed here are eligible for dialogue interactions.
	-- Interaction services read this map to avoid showing prompts for combat-only NPCs.
	NPCS = table.freeze({
		Eldric = table.freeze({
			NPCId = "Eldric",
			DisplayName = "Eldric the Elder",
		}),
		VillagerCustomerNoOffer = table.freeze({
			NPCId = "VillagerCustomerNoOffer",
			DisplayName = "Villager",
		}),
		VillagerCustomerWithOffer = table.freeze({
			NPCId = "VillagerCustomerWithOffer",
			DisplayName = "Villager",
		}),
		VillagerFarewellAccepted = table.freeze({
			NPCId = "VillagerFarewellAccepted",
			DisplayName = "Villager",
		}),
		VillagerFarewellDeclined = table.freeze({
			NPCId = "VillagerFarewellDeclined",
			DisplayName = "Villager",
		}),
	}),

	INTERACTION_TAGS = table.freeze({
		"NPC",
		"CombatNPC",
	}),
})
