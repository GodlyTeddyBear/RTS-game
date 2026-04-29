--!strict

local Types = require(script.Parent.Types)

type TConfig = Types.TConfig
type THook = Types.THook
type TActorAdapter = Types.TActorAdapter
type TFrameContext = Types.TFrameContext

local REQUIRED_ADAPTER_METHODS = table.freeze({
	"QueryActiveEntities",
	"GetBehaviorTree",
	"GetActionState",
	"SetActionState",
	"ClearActionState",
	"SetPendingAction",
	"UpdateLastTickTime",
	"ShouldEvaluate",
})

local Validation = {}

function Validation.ValidateConfig(config: TConfig)
	assert(type(config) == "table", "AiRuntime config must be a table")
	assert(type(config.Conditions) == "table", "AiRuntime config.Conditions must be a table")
	assert(type(config.Commands) == "table", "AiRuntime config.Commands must be a table")
	assert(type(config.Hooks) == "table", "AiRuntime config.Hooks must be a table")

	for index, hook: THook in ipairs(config.Hooks) do
		assert(type(hook) == "table", ("AiRuntime hook #%d must be a table"):format(index))
		assert(type(hook.Use) == "function", ("AiRuntime hook #%d must expose Use"):format(index))
	end

	if config.ErrorSink ~= nil then
		assert(type(config.ErrorSink) == "function", "AiRuntime config.ErrorSink must be a function")
	end
end

function Validation.ValidateActorType(actorType: string)
	assert(type(actorType) == "string" and #actorType > 0, "AiRuntime actorType must be a non-empty string")
end

function Validation.ValidateActorAdapter(actorType: string, adapter: TActorAdapter)
	assert(type(adapter) == "table", ("AiRuntime actor adapter '%s' must be a table"):format(actorType))

	for _, methodName in ipairs(REQUIRED_ADAPTER_METHODS) do
		assert(
			type((adapter :: any)[methodName]) == "function",
			("AiRuntime actor adapter '%s' must expose %s"):format(actorType, methodName)
		)
	end

	local getActorLabel = (adapter :: any).GetActorLabel
	if getActorLabel ~= nil then
		assert(
			type(getActorLabel) == "function",
			("AiRuntime actor adapter '%s' GetActorLabel must be a function"):format(actorType)
		)
	end
end

function Validation.ValidateFrameContext(frameContext: TFrameContext)
	assert(type(frameContext) == "table", "AiRuntime RunFrame requires a frameContext table")
	assert(type(frameContext.CurrentTime) == "number", "AiRuntime frameContext.CurrentTime must be a number")

	if frameContext.DeltaTime ~= nil then
		assert(type(frameContext.DeltaTime) == "number", "AiRuntime frameContext.DeltaTime must be a number")
	end

	if frameContext.Services ~= nil then
		assert(type(frameContext.Services) == "table", "AiRuntime frameContext.Services must be a table")
	end

	if frameContext.ActorTypes ~= nil then
		assert(type(frameContext.ActorTypes) == "table", "AiRuntime frameContext.ActorTypes must be a string array")
		for index, actorType in ipairs(frameContext.ActorTypes) do
			assert(
				type(actorType) == "string" and #actorType > 0,
				("AiRuntime frameContext.ActorTypes[%d] must be a non-empty string"):format(index)
			)
		end
	end
end

return table.freeze(Validation)
