--!strict

return table.freeze({
	INVALID_WORKER_TYPE = "Worker type does not exist",
	WORKER_NOT_FOUND = "Worker does not exist",
	INVALID_ROLE = "Role does not exist",
	WORKER_ALREADY_ASSIGNED = "Worker is already assigned to a production line",
	PLAYER_NOT_FOUND = "Player not found",
	WORKER_NOT_MINER = "Worker must have the Miner role to be assigned an ore",
	WORKER_NOT_FORGE = "Worker must have the Forge role to be assigned a recipe",
	INVALID_ORE_TYPE = "Ore type does not exist",
	ORE_NOT_IN_LOT = "Ore is not available in this lot's mine zone",
	ORE_AT_MAX_WORKERS = "This ore already has the maximum number of workers assigned",
	LOT_NOT_FOUND = "Player does not have a lot",
	MINING_NO_TARGET = "Miner has no ore target assigned",
	RECIPE_NOT_FOUND = "Recipe does not exist",
	RECIPE_NOT_AUTOMATABLE = "Recipe cannot be automated by workers",
	INSUFFICIENT_MATERIALS = "Not enough materials in inventory",

	-- Tick system specs
	NOT_NEAR_ORE = "Miner is not within proximity of the ore node",
	MINING_NOT_COMPLETE = "Mining action has not completed yet",
	ORE_NOT_FOUND = "Ore instance no longer exists in the lot",
	NOT_ELIGIBLE_FOR_PRODUCTION = "Worker is not eligible for production this tick",
	NO_RECIPE_ASSIGNED = "Forge worker has no recipe assigned",
	PRODUCTION_NOT_READY = "Worker has not accumulated enough production",
	INSUFFICIENT_INGREDIENTS = "Not enough ingredients to craft recipe",
	FORGE_RECIPE_NEEDS_MACHINE = "This forge recipe must be made at a building, not by a worker",
	FORGE_RECIPE_LOCKED = "This forge recipe has not been unlocked yet",
	FORGE_BUILDING_REQUIRED = "Required forge building is not available in this lot",

	-- Brewery
	WORKER_NOT_BREWERY = "Worker must have the Brewery role to be assigned a brew recipe",
	BREWERY_RECIPE_NOT_FOUND = "Brewery recipe does not exist",
	BREWERY_RECIPE_NOT_AUTOMATABLE = "Brewery recipe cannot be automated by workers",
	BREWERY_RECIPE_LOCKED = "This brewery recipe has not been unlocked yet",
	BREWERY_BUILDING_REQUIRED = "Required brewery building is not available in this lot",
	NO_BREW_RECIPE_ASSIGNED = "Brewer worker has no recipe assigned",
	INSUFFICIENT_BREW_INGREDIENTS = "Not enough ingredients to brew recipe",

	-- Tailor
	WORKER_NOT_TAILOR = "Worker must have the Tailor role to be assigned a tailoring recipe",
	TAILORING_RECIPE_NOT_FOUND = "Tailoring recipe does not exist",
	TAILORING_RECIPE_NOT_AUTOMATABLE = "Tailoring recipe cannot be automated by workers",
	NO_TAILORING_RECIPE_ASSIGNED = "Tailor worker has no recipe assigned",
	INSUFFICIENT_TAILORING_INGREDIENTS = "Not enough ingredients to tailor recipe",

	-- Lumberjack
	WORKER_NOT_LUMBERJACK = "Worker must have the Lumberjack role to be assigned a tree",
	INVALID_TREE_TYPE = "Tree type does not exist",
	TREE_NOT_IN_LOT = "Tree is not available in this lot's forest zone",
	TREE_AT_MAX_WORKERS = "This tree already has the maximum number of workers assigned",
	FOREST_NOT_FOUND = "Player does not have a forest zone",
	TREE_NOT_FOUND = "Tree instance no longer exists in the lot",
	NOT_NEAR_TREE = "Lumberjack is not within proximity of the tree",
	CHOPPING_NOT_COMPLETE = "Chopping action has not completed yet",

	-- Herbalist
	WORKER_NOT_HERBALIST = "Worker must have the Herbalist role to be assigned a plant",
	INVALID_PLANT_TYPE = "Plant type does not exist",
	PLANT_NOT_IN_LOT = "Plant is not available in this lot's garden zone",
	PLANT_AT_MAX_WORKERS = "This plant already has the maximum number of workers assigned",
	GARDEN_NOT_FOUND = "Player does not have a garden zone",
	PLANT_NOT_FOUND = "Plant instance no longer exists in the lot",
	NOT_NEAR_PLANT = "Herbalist is not within proximity of the plant",
	HARVESTING_NOT_COMPLETE = "Harvesting action has not completed yet",

	-- Ranks (kept for legacy safety; auto-promotion means these are never triggered by normal play)
	RANK_NOT_FOUND = "Rank does not exist",

	-- Unlock
	NOT_UNLOCKED = "This content has not been unlocked yet",

	-- Farmer
	WORKER_NOT_FARMER = "Worker must have the Farmer role to be assigned a crop",
	INVALID_CROP_TYPE = "Crop type does not exist",
	CROP_NOT_IN_LOT = "Crop is not available in this lot's farm zone",
	CROP_AT_MAX_WORKERS = "This crop already has the maximum number of workers assigned",
	FARM_NOT_FOUND = "Player does not have a farm zone",
	CROP_NOT_FOUND = "Crop instance no longer exists in the lot",
	NOT_NEAR_CROP = "Farmer is not within proximity of the crop",
	GROWING_NOT_COMPLETE = "Crop has not finished growing yet",
})
