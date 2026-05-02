--!strict

--[=[
    @class Errors
    Shared actor-registry error constants used by the base registry and its derived
    validation helpers.
    @server
    @client
]=]

local Errors = {}

--[=[
    @prop RUNTIME_ALREADY_STARTED string
    @within Errors
    @readonly
    Returned when a registry tries to register a type after runtime startup.
]=]
Errors.RUNTIME_ALREADY_STARTED = "ActorRegistryBase: runtime is already started"

--[=[
    @prop DUPLICATE_ACTOR_TYPE string
    @within Errors
    @readonly
    Returned when an actor type is registered more than once.
]=]
Errors.DUPLICATE_ACTOR_TYPE = "ActorRegistryBase: actor type is already registered"

--[=[
    @prop UNKNOWN_ACTOR_TYPE string
    @within Errors
    @readonly
    Returned when an actor payload references an unregistered type.
]=]
Errors.UNKNOWN_ACTOR_TYPE = "ActorRegistryBase: actor type is not registered"

--[=[
    @prop DUPLICATE_ACTOR_HANDLE string
    @within Errors
    @readonly
    Returned when an actor handle is already claimed by a live or pending record.
]=]
Errors.DUPLICATE_ACTOR_HANDLE = "ActorRegistryBase: actor handle is already registered"

--[=[
    @prop UNKNOWN_ACTOR_HANDLE string
    @within Errors
    @readonly
    Returned when an unregister request references no known actor handle.
]=]
Errors.UNKNOWN_ACTOR_HANDLE = "ActorRegistryBase: actor handle is not registered"

--[=[
    @prop MISSING_ACTOR_RUNTIME_BINDING string
    @within Errors
    @readonly
    Returned when shared actor metadata requires runtime binding details but none exist.
]=]
Errors.MISSING_ACTOR_RUNTIME_BINDING = "ActorRegistryBase: actor type semantic requirements are missing runtime binding metadata"

--[=[
    @prop INVALID_ACTOR_RUNTIME_BINDING_OWNER string
    @within Errors
    @readonly
    Returned when the runtime binding owner cannot report scheduler binding status.
]=]
Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER = "ActorRegistryBase: actor type runtime binding owner is invalid"

--[=[
    @prop ACTOR_POLL_REQUIREMENT_UNSATISFIED string
    @within Errors
    @readonly
    Returned when polling requirements are declared but the runtime owner cannot satisfy them.
]=]
Errors.ACTOR_POLL_REQUIREMENT_UNSATISFIED = "ActorRegistryBase: actor type polling requirement is not satisfied"

--[=[
    @prop ACTOR_PROJECTION_REQUIREMENT_UNSATISFIED string
    @within Errors
    @readonly
    Returned when projection requirements are declared but the runtime owner cannot satisfy them.
]=]
Errors.ACTOR_PROJECTION_REQUIREMENT_UNSATISFIED = "ActorRegistryBase: actor type projection requirement is not satisfied"

--[=[
    @prop INVALID_ACTOR_TYPE_PAYLOAD string
    @within Errors
    @readonly
    Returned when the actor type registration payload fails shared validation.
]=]
Errors.INVALID_ACTOR_TYPE_PAYLOAD = "ActorRegistryBase: invalid actor type registration payload"

--[=[
    @prop INVALID_SETUP_MISSING_ACTOR_TYPES string
    @within Errors
    @readonly
    Returned when shared setup validation cannot find the actor-type storage table.
]=]
Errors.INVALID_SETUP_MISSING_ACTOR_TYPES = "ActorRegistryBase setup is missing _actorTypes"

--[=[
    @prop INVALID_SETUP_MISSING_RECORDS_BY_RUNTIME_ID string
    @within Errors
    @readonly
    Returned when shared setup validation cannot find the runtime-record storage table.
]=]
Errors.INVALID_SETUP_MISSING_RECORDS_BY_RUNTIME_ID = "ActorRegistryBase setup is missing _recordsByRuntimeId"

--[=[
    @prop INVALID_SETUP_MISSING_RUNTIME_IDS_BY_HANDLE string
    @within Errors
    @readonly
    Returned when shared setup validation cannot find the handle index table.
]=]
Errors.INVALID_SETUP_MISSING_RUNTIME_IDS_BY_HANDLE = "ActorRegistryBase setup is missing _runtimeIdsByHandle"

--[=[
    @prop INVALID_SETUP_MISSING_RUNTIME_IDS_BY_ACTOR_TYPE string
    @within Errors
    @readonly
    Returned when shared setup validation cannot find the actor-type runtime-id index table.
]=]
Errors.INVALID_SETUP_MISSING_RUNTIME_IDS_BY_ACTOR_TYPE = "ActorRegistryBase setup is missing _runtimeIdsByActorType"

--[=[
    @prop INVALID_SETUP_MISSING_PENDING_ACTOR_PAYLOADS string
    @within Errors
    @readonly
    Returned when shared setup validation cannot find the pending actor payload table.
]=]
Errors.INVALID_SETUP_MISSING_PENDING_ACTOR_PAYLOADS = "ActorRegistryBase setup is missing _pendingActorPayloadsByHandle"

--[=[
    @prop INVALID_SETUP_NON_NUMERIC_NEXT_RUNTIME_ID string
    @within Errors
    @readonly
    Returned when the runtime id counter is not numeric during setup validation.
]=]
Errors.INVALID_SETUP_NON_NUMERIC_NEXT_RUNTIME_ID = "ActorRegistryBase setup has a non-numeric _nextRuntimeId"

--[=[
    @prop INVALID_SETUP_NON_BOOLEAN_RUNTIME_STARTED_FLAG string
    @within Errors
    @readonly
    Returned when the runtime-started flag is not boolean during setup validation.
]=]
Errors.INVALID_SETUP_NON_BOOLEAN_RUNTIME_STARTED_FLAG = "ActorRegistryBase setup has a non-boolean _runtimeStarted flag"

--[=[
    @prop INVALID_SETUP_MISSING_OVERRIDE_HOOK string
    @within Errors
    @readonly
    Returned when a required override hook is missing or not overridden.
]=]
Errors.INVALID_SETUP_MISSING_OVERRIDE_HOOK = "ActorRegistryBase setup must override hook"

--[=[
    @prop INVALID_SETUP_MISSING_HOOK string
    @within Errors
    @readonly
    Returned when a required abstract hook is missing during setup validation.
]=]
Errors.INVALID_SETUP_MISSING_HOOK = "ActorRegistryBase setup is missing hook"

--[=[
    @prop INVALID_SETUP_MISSING_RUNTIME_METHOD string
    @within Errors
    @readonly
    Returned when a required runtime method is missing during setup validation.
]=]
Errors.INVALID_SETUP_MISSING_RUNTIME_METHOD = "ActorRegistryBase setup is missing runtime method"

return table.freeze(Errors)
