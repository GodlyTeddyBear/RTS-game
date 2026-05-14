--!strict

local BaseConfig = {}

BaseConfig.BASE_ID = "PrimaryBase"
BaseConfig.MAX_HP = 30000
BaseConfig.BASE_MARKER_NAME = "Base"
BaseConfig.REVEAL_NAMESPACE = "Base"
BaseConfig.REVEAL_ENTITY_TYPE = "PrimaryBase"
BaseConfig.REVEAL_SCOPE_ID = "Global"
BaseConfig.UNIT_PRODUCTION_SIDE_OFFSET = 10
BaseConfig.UNIT_PRODUCTION_FORWARD_START = -6
BaseConfig.UNIT_PRODUCTION_FORWARD_SPACING = 4
BaseConfig.UNIT_PRODUCTION_SLOTS_PER_ROW = 4
BaseConfig.UNIT_PRODUCTION_ROW_STEP = 4

return table.freeze(BaseConfig)
