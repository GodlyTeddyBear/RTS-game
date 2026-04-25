--!strict

local MiningConfig = {}

MiningConfig.EXTRACTOR_STRUCTURE_TYPE = "Extractor"
MiningConfig.BASE_RATE_SECONDS = 5
MiningConfig.BASE_AMOUNT_PER_CYCLE = 1

return table.freeze(MiningConfig)
