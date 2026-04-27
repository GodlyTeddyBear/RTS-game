--!strict

local MiningConfig = {}

MiningConfig.EXTRACTOR_STRUCTURE_TYPE = "Extractor"
MiningConfig.RESOURCE_ZONE_NAME = "Resources"
MiningConfig.BASE_RATE_SECONDS = 5
MiningConfig.BASE_AMOUNT_PER_CYCLE = 1
MiningConfig.MANUAL_GATHER_AMOUNT = 1
MiningConfig.MANUAL_GATHER_COOLDOWN_SECONDS = 0.5
MiningConfig.MANUAL_GATHER_MAX_DISTANCE = 24

return table.freeze(MiningConfig)
