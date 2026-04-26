--!strict

local EXECUTOR_SUFFIX = "Executor"

local function _GetActionId(moduleName: string): string
	assert(
		moduleName:sub(-#EXECUTOR_SUFFIX) == EXECUTOR_SUFFIX,
		string.format("Combat executor module '%s' must end with '%s'", moduleName, EXECUTOR_SUFFIX)
	)

	local actionId = moduleName:sub(1, #moduleName - #EXECUTOR_SUFFIX)
	assert(actionId ~= "", string.format("Combat executor module '%s' produced an empty action id", moduleName))

	return actionId
end

local function _GetExecutorModules(): { ModuleScript }
	local executorModules = {}
	for _, child in ipairs(script:GetChildren()) do
		if child.Name == "init" then
			continue
		end
		assert(
			child:IsA("ModuleScript"),
			string.format("Combat executor child '%s' must be a ModuleScript", child.Name)
		)
		table.insert(executorModules, child)
	end

	table.sort(executorModules, function(left: ModuleScript, right: ModuleScript): boolean
		return left.Name < right.Name
	end)

	return executorModules
end

local function _BuildActionDefinitions(): { [string]: any }
	local actionDefinitions = {}

	for _, executorModuleScript: ModuleScript in ipairs(_GetExecutorModules()) do
		local actionId = _GetActionId(executorModuleScript.Name)
		assert(actionDefinitions[actionId] == nil, string.format("Combat action '%s' is registered twice", actionId))

		local executorModule = require(executorModuleScript)
		assert(
			type(executorModule) == "table" and type(executorModule.new) == "function",
			string.format("Combat executor module '%s' must expose .new", executorModuleScript.Name)
		)

		actionDefinitions[actionId] = table.freeze({
			ActionId = actionId,
			CreateExecutor = executorModule.new,
		})
	end

	return table.freeze(actionDefinitions)
end

return _BuildActionDefinitions()
