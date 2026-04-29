--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TActorSetupResult = Types.TActorSetupResult
type TActorSetupWriteConfig = Types.TActorSetupWriteConfig
type TFactorySetupWriteConfig = Types.TFactorySetupWriteConfig
type TActorSetupWriteResult = Types.TActorSetupWriteResult

--[=[
	@class AISetupWriter
	Builds setup-writer configurations and writes resolved actor setups into caller-owned storage.
	@server
	@client
]=]

local SetupWriter = {}

local function _BuildSurfaceInvoker(factoryObject: any, surface: any): (setupResult: TActorSetupResult) -> ()
	-- String surfaces let callers point at methods on the factory object without wrapping them manually.
	if type(surface) == "string" then
		return function(setupResult: TActorSetupResult)
			local method = factoryObject[surface]
			assert(type(method) == "function", ("AI setup writer factory is missing method '%s'"):format(surface))
			method(factoryObject, setupResult)
		end
	end

	return function(setupResult: TActorSetupResult)
		surface(factoryObject, setupResult)
	end
end

--[=[
	Creates a setup-writer configuration backed by one factory object.
	@within AISetupWriter
	@param config TFactorySetupWriteConfig
	@return TActorSetupWriteConfig
]=]
function SetupWriter.CreateFactory(config: TFactorySetupWriteConfig): TActorSetupWriteConfig
	Validation.ValidateFactorySetupWriteConfig(config)

	local writeConfig = {
		WriteSetup = _BuildSurfaceInvoker(config.Factory, config.WriteSetup),
		ClearActionState = nil,
		OnMissingBehavior = nil,
	}

	if config.ClearActionState ~= nil then
		writeConfig.ClearActionState = _BuildSurfaceInvoker(config.Factory, config.ClearActionState)
	end

	if config.OnMissingBehavior ~= nil then
		writeConfig.OnMissingBehavior = _BuildSurfaceInvoker(config.Factory, config.OnMissingBehavior)
	end

	return table.freeze(writeConfig)
end

--[=[
	Writes one resolved actor setup through one writer configuration.
	@within AISetupWriter
	@param setupResult TActorSetupResult
	@param config TActorSetupWriteConfig
	@return TActorSetupWriteResult
]=]
function SetupWriter.WriteOne(setupResult: TActorSetupResult, config: TActorSetupWriteConfig): TActorSetupWriteResult
	Validation.ValidateActorSetupResult(setupResult)
	Validation.ValidateActorSetupWriteConfig(config)

	local wroteSetup = false

	if setupResult.Found then
		-- A resolved behavior writes the setup first, then optionally clears transient action state.
		config.WriteSetup(setupResult)
		wroteSetup = true

		if setupResult.InitializeActionState and config.ClearActionState ~= nil then
			config.ClearActionState(setupResult)
		end
	elseif config.OnMissingBehavior ~= nil then
		-- Missing-behavior callbacks only run when the build result could not resolve a tree.
		config.OnMissingBehavior(setupResult)
	end

	return table.freeze({
		Entity = setupResult.Entity,
		ActorType = setupResult.ActorType,
		Found = setupResult.Found,
		WroteSetup = wroteSetup,
		BehaviorName = setupResult.BehaviorName,
		ResolvedBehaviorName = setupResult.ResolvedBehaviorName,
	})
end

--[=[
	Writes many resolved actor setups in order through one writer configuration.
	@within AISetupWriter
	@param setupResults { TActorSetupResult }
	@param config TActorSetupWriteConfig
	@return { TActorSetupWriteResult }
]=]
function SetupWriter.WriteMany(
	setupResults: { TActorSetupResult },
	config: TActorSetupWriteConfig
): { TActorSetupWriteResult }
	Validation.ValidateActorSetupResults(setupResults)
	Validation.ValidateActorSetupWriteConfig(config)

	local writeResults = {}
	for _, setupResult in ipairs(setupResults) do
		table.insert(writeResults, SetupWriter.WriteOne(setupResult, config))
	end

	-- Batch writes preserve request order so callers can align output with the original setup list.
	return table.freeze(writeResults)
end

return table.freeze(SetupWriter)
