--!strict

return table.freeze({
	SPAWN_INTERVAL_SECONDS = 20,
	MAX_CUSTOMERS = 4,
	MAX_MERCHANTS = 2,
	BEHAVIOR_TICK_INTERVAL = 0.5,
	CUSTOMER_WAIT_SECONDS = 120,
	PATH_TIMEOUT_SECONDS = 30,
	COLLISION_GROUP = "Villagers",
	COLLIDES_WITH_VILLAGERS = false,

	Archetypes = table.freeze({
		Customer = table.freeze({
			Id = "Customer",
			DisplayName = "Villager",
			ModelKey = "Customer",
			BehaviorType = "Customer",
			SpawnWeight = 10,
			MerchantShopId = nil,
		}),
		Merchant = table.freeze({
			Id = "Merchant",
			DisplayName = "Traveling Merchant",
			ModelKey = "Merchant",
			BehaviorType = "Merchant",
			SpawnWeight = 2,
			MerchantShopId = "TravelingMerchant",
		}),
	}),
})
