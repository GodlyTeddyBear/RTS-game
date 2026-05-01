--!strict

local Errors = {}

Errors.RUNTIME_ALREADY_STARTED = "ActorRegistryBase: runtime is already started"
Errors.DUPLICATE_ACTOR_TYPE = "ActorRegistryBase: actor type is already registered"
Errors.UNKNOWN_ACTOR_TYPE = "ActorRegistryBase: actor type is not registered"
Errors.DUPLICATE_ACTOR_HANDLE = "ActorRegistryBase: actor handle is already registered"
Errors.UNKNOWN_ACTOR_HANDLE = "ActorRegistryBase: actor handle is not registered"
Errors.MISSING_ACTOR_RUNTIME_BINDING = "ActorRegistryBase: actor type semantic requirements are missing runtime binding metadata"
Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER = "ActorRegistryBase: actor type runtime binding owner is invalid"
Errors.ACTOR_POLL_REQUIREMENT_UNSATISFIED = "ActorRegistryBase: actor type polling requirement is not satisfied"
Errors.ACTOR_PROJECTION_REQUIREMENT_UNSATISFIED = "ActorRegistryBase: actor type projection requirement is not satisfied"
Errors.INVALID_ACTOR_TYPE_PAYLOAD = "ActorRegistryBase: invalid actor type registration payload"

return table.freeze(Errors)
