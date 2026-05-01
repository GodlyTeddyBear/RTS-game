--!strict

local Errors = {}

Errors.INVALID_EXTRACTOR_RECORD = "MiningContext: extractor record is invalid"
Errors.INVALID_OWNER = "MiningContext: extractor owner is invalid"
Errors.INVALID_RESOURCE_TYPE = "MiningContext: extractor resource type is invalid"
Errors.INVALID_INSTANCE_ID = "MiningContext: extractor instance id is invalid"
Errors.INVALID_INTERVAL = "MiningContext: extractor interval must be positive"
Errors.INVALID_AMOUNT = "MiningContext: extractor amount must be a positive integer"
Errors.MISSING_RESOURCE_ZONE = "MiningContext: resources zone is missing from the runtime map"
Errors.INVALID_RESOURCE_ZONE = "MiningContext: resources zone instance is invalid"
Errors.INVALID_RESOURCE_NODE = "MiningContext: resource node part is invalid"
Errors.UNKNOWN_RESOURCE_NODE_TYPE = "MiningContext: resource node part name must match a known resource type"
Errors.INVALID_PLAYER = "MiningContext: player is invalid"
Errors.UNREGISTERED_RESOURCE_NODE = "MiningContext: resource node is not registered"
Errors.RESOURCE_GATHER_COOLDOWN = "MiningContext: resource node was gathered too recently"
Errors.INVALID_ACTOR_TYPE_PAYLOAD = "MiningContext: mining actor-type payload is invalid"
Errors.INVALID_ACTOR_PAYLOAD = "MiningContext: mining actor payload is invalid"
Errors.RUNTIME_ALREADY_STARTED = "MiningContext: mining runtime already started"
Errors.RUNTIME_START_FAILED = "MiningContext: mining runtime failed to start"
Errors.RUNTIME_NOT_STARTED = "MiningContext: mining runtime is not started"

return table.freeze(Errors)
