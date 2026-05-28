--!strict

local Errors = table.freeze({
	AI_ENTITY_SCHEMA_REGISTRATION_FAILED = "AI:Entity schema registration failed",
	AI_ENTITY_SYSTEM_REGISTRATION_FAILED = "AI:Entity system registration failed",
	AI_ENTITY_CLEANUP_REGISTRATION_FAILED = "AI:Entity cleanup registration failed",
	DUPLICATE_ACTION_DEFINITION = "AI:Action definition is already registered",
	DUPLICATE_BEHAVIOR_DEFINITION = "AI:Behavior definition is already registered",
	DUPLICATE_EVALUATION = "AI:Evaluation is already registered",
	DUPLICATE_FACT_KEY = "AI:Fact provider produced a duplicate fact key",
	DUPLICATE_FACT_PROVIDER = "AI:Fact provider is already registered",
	DUPLICATE_PROFILE = "AI:Entity AI profile is already registered",
	AMBIGUOUS_BEHAVIOR_LEAF = "AI:Behavior definition leaf is registered as both evaluation and action",
	AI_FACT_BUILD_FAILED = "AI:Fact provider failed to build facts",
	AI_SEED_FAILED = "AI:Built-in definition seed failed",
	BEHAVIOR_DEFINITION_TOO_DEEP = "AI:Behavior definition exceeds maximum depth",
	BEHAVIOR_DEFINITION_COMPILATION_FAILED = "AI:Behavior definition compilation failed",
	BEHAVIOR_TREE_EXECUTION_FAILED = "AI:Behavior tree execution failed",
	EVALUATION_SKIPPED_BY_TICK_INTERVAL = "AI:Evaluation skipped by tick interval",
	INVALID_ACTION_DEFINITION = "AI:Invalid action definition",
	INVALID_ACTION_INTENT = "AI:Invalid action intent",
	INVALID_BEHAVIOR_DEFINITION = "AI:Invalid behavior definition",
	INVALID_ENTITY_PROFILE = "AI:Invalid entity profile",
	INVALID_EVALUATION = "AI:Invalid evaluation",
	INVALID_FACT_PROVIDER = "AI:Invalid fact provider",
	INVALID_PROFILE = "AI:Invalid entity AI profile",
	MISSING_AI_SETUP_COMPONENT = "AI:Missing AI setup component",
	UNKNOWN_AI_PROFILE = "AI:Entity AI profile is not registered",
	UNKNOWN_BEHAVIOR_DEFINITION = "AI:Behavior definition is not registered",
	UNKNOWN_BEHAVIOR_LEAF = "AI:Behavior definition leaf is not registered",
	UNKNOWN_ENTITY = "AI:Entity does not exist",
})

return Errors
