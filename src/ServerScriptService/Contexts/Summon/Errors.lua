--!strict

local Errors = {}

Errors.INVALID_PLAYER = "SummonContext: player is required"
Errors.INVALID_CAST_ORIGIN = "SummonContext: cast origin is required"
Errors.INVALID_METADATA = "SummonContext: slot metadata is invalid"
Errors.SUMMON_NOT_AVAILABLE = "SummonContext: swarm drones can only be used during Wave or Endless"
Errors.INVALID_SUMMON_COUNT = "SummonContext: summon count must be a positive integer"
Errors.INVALID_LIFETIME = "SummonContext: summon lifetime must be positive"
Errors.MAX_CONCURRENT_REACHED = "SummonContext: max concurrent swarm drones reached"

return table.freeze(Errors)
