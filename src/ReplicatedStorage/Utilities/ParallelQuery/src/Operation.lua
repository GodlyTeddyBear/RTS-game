--!strict

local RowDefaults = require(script.Parent.RowDefaults)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TResultField = Types.TResultField
type TStaticOperationDefinition = Types.TStaticOperationDefinition

type TAuthoringOperationConfig = {
	Name: string,
	ResultSchema: { TResultField },
	Execute: (taskId: number, memory: SharedTable?, ...any) -> Types.TOperationRow,
	CacheLocalMemory: boolean?,
	InitialLocalMemory: SharedTable?,
}

local Operation = {}

local function _CreateDefinition(config: TAuthoringOperationConfig, cacheLocalMemory: boolean?): TStaticOperationDefinition
	assert(type(config) == "table", "ParallelQuery.Operation requires a config table")
	assert(type(config.Name) == "string" and config.Name ~= "", "ParallelQuery.Operation requires Name")
	assert(type(config.Execute) == "function", `ParallelQuery.Operation "{config.Name}" requires Execute`)
	assert(type(config.ResultSchema) == "table" and #config.ResultSchema > 0, `ParallelQuery.Operation "{config.Name}" requires ResultSchema`)

	Validation.AssertSchema(config.ResultSchema, config.Name)
	if config.InitialLocalMemory ~= nil then
		Validation.AssertSharedMemory(config.InitialLocalMemory, config.Name)
	end

	local definition: TStaticOperationDefinition = {
		Name = config.Name,
		ResultSchema = config.ResultSchema,
		CacheLocalMemory = if cacheLocalMemory ~= nil then cacheLocalMemory else config.CacheLocalMemory,
		Execute = config.Execute,
		InitialLocalMemory = config.InitialLocalMemory,
		BuildEmptyRow = function(self, overrides: { [string]: any }?): { [string]: any }
			return RowDefaults.BuildNamedRow(self.ResultSchema, overrides)
		end,
	}

	return table.freeze(definition)
end

function Operation.EmptyRow(schema: { TResultField }, overrides: { [string]: any }?): { [string]: any }
	return RowDefaults.BuildNamedRow(schema, overrides)
end

function Operation.Define(config: TAuthoringOperationConfig): TStaticOperationDefinition
	return _CreateDefinition(config, nil)
end

function Operation.DefineCached(config: TAuthoringOperationConfig): TStaticOperationDefinition
	return _CreateDefinition(config, true)
end

return table.freeze(Operation)
