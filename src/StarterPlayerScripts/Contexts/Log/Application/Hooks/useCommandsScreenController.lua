--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Knit = require(ReplicatedStorage.Packages.Knit)
local LogCommandTypes = require(ReplicatedStorage.Contexts.Log.Types.LogCommandTypes)

local useCommands = require(script.Parent.useCommands)
local CommandsViewModel = require(script.Parent.Parent.ViewModels.CommandsViewModel)

type CommandManifestEntry = LogCommandTypes.CommandManifestEntry
type CommandExecutionResult = LogCommandTypes.CommandExecutionResult
type GroupedCommands = CommandsViewModel.GroupedCommands

type ParamValuesByCommand = { [string]: { [string]: string } }
type ExecutionResultsByCommand = { [string]: CommandExecutionResult & { timestamp: number } }
type BoolMap = { [string]: boolean }

export type TCommandsScreenController = {
	groupedCommands: { GroupedCommands },
	expandedCommands: BoolMap,
	paramValues: ParamValuesByCommand,
	executionResults: ExecutionResultsByCommand,
	isExecuting: BoolMap,
	onToggleExpand: (commandName: string) -> (),
	onParamChange: (commandName: string, paramName: string, value: string) -> (),
	onExecute: (commandName: string) -> (),
}

local function _buildDefaultParamValues(manifest: { CommandManifestEntry }): ParamValuesByCommand
	local defaults: ParamValuesByCommand = {}

	for _, command in ipairs(manifest) do
		local valuesByParam: { [string]: string } = {}
		local params = command.params
		if params ~= nil then
			for _, param in ipairs(params) do
				valuesByParam[param.name] = param.default or ""
			end
		end
		defaults[command.name] = valuesByParam
	end

	return defaults
end

local function _cloneParamValues(values: ParamValuesByCommand, commandName: string): { [string]: string }
	local existing = values[commandName]
	return if existing ~= nil then table.clone(existing) else {}
end

local function useCommandsScreenController(): TCommandsScreenController
	local manifest = useCommands()

	local groupedCommands = React.useMemo(function()
		return CommandsViewModel.build(manifest)
	end, { manifest })

	local manifestByName = React.useMemo(function()
		local map: { [string]: CommandManifestEntry } = {}
		for _, command in ipairs(manifest) do
			map[command.name] = command
		end
		return map
	end, { manifest })

	local defaultParamValues = React.useMemo(function()
		return _buildDefaultParamValues(manifest)
	end, { manifest })

	local expandedCommands, setExpandedCommands = React.useState({} :: BoolMap)
	local paramValues, setParamValues = React.useState(defaultParamValues)
	local executionResults, setExecutionResults = React.useState({} :: ExecutionResultsByCommand)
	local isExecuting, setIsExecuting = React.useState({} :: BoolMap)

	React.useEffect(function()
		setParamValues(defaultParamValues)
	end, { defaultParamValues })

	local onToggleExpand = React.useCallback(function(commandName: string)
		setExpandedCommands(function(current: BoolMap)
			local updated = table.clone(current)
			updated[commandName] = not current[commandName]
			return updated
		end)
	end, {})

	local onParamChange = React.useCallback(function(commandName: string, paramName: string, value: string)
		setParamValues(function(current: ParamValuesByCommand)
			local updated = table.clone(current)
			local commandParams = _cloneParamValues(current, commandName)
			commandParams[paramName] = value
			updated[commandName] = commandParams
			return updated
		end)
	end, {})

	local onExecute = React.useCallback(function(commandName: string)
		if isExecuting[commandName] then
			return
		end

		setIsExecuting(function(current: BoolMap)
			local updated = table.clone(current)
			updated[commandName] = true
			return updated
		end)

		local paramsForCommand = _cloneParamValues(paramValues, commandName)
		local logContext = Knit.GetService("LogContext")

		local success = false
		local message = "Unknown execution error"

		local ok, result = pcall(function()
			return logContext:ExecuteCommand(commandName, paramsForCommand)
		end)

		if ok and type(result) == "table" then
			local typedResult = result :: CommandExecutionResult
			success = typedResult.success == true
			message = tostring(typedResult.message)
		elseif not ok then
			message = tostring(result)
		end

		setExecutionResults(function(current: ExecutionResultsByCommand)
			local updated = table.clone(current)
			updated[commandName] = {
				success = success,
				message = message,
				timestamp = os.clock(),
			}
			return updated
		end)

		local manifestEntry = manifestByName[commandName]
		setParamValues(function(current: ParamValuesByCommand)
			local updated = table.clone(current)
			local resetValues: { [string]: string } = {}
			local params = if manifestEntry ~= nil then manifestEntry.params else nil
			if params ~= nil then
				for _, param in ipairs(params) do
					resetValues[param.name] = param.default or ""
				end
			end
			updated[commandName] = resetValues
			return updated
		end)

		setIsExecuting(function(current: BoolMap)
			local updated = table.clone(current)
			updated[commandName] = nil
			return updated
		end)
	end, { isExecuting, paramValues, manifestByName })

	return {
		groupedCommands = groupedCommands,
		expandedCommands = expandedCommands,
		paramValues = paramValues,
		executionResults = executionResults,
		isExecuting = isExecuting,
		onToggleExpand = onToggleExpand,
		onParamChange = onParamChange,
		onExecute = onExecute,
	}
end

return useCommandsScreenController
