--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

-- Modules
local Knit = require(ReplicatedStorage.Packages.Knit)
local TestEZ = require(ReplicatedStorage.Packages.Testez)

-- Constants
local RUN_TESTS = false
local BANNER_WIDTH = 70
local REPORTER = TestEZ.Reporters.TextReporter
local SPEC_NAME_FILTERS = {
	-- "BaseECSReplicationClient",
	-- "ActorRegistryBase",
}
local TEST_CONTAINERS = {
	ReplicatedStorage,
	ServerStorage,
	ServerScriptService,
}

type TTestResults = {
	successCount: number,
	failureCount: number,
}

local function _PrintDivider()
	print(string.rep("=", BANNER_WIDTH))
end

local function _PrintSuiteHeader(testCount: number)
	print("")
	_PrintDivider()
	print("GLOBAL TEST SUITE")
	print(("Discovered %d test modules"):format(testCount))
	_PrintDivider()
	print("")
end

local function _PrintEmptySuiteWarning()
	print("")
	_PrintDivider()
	warn("TEST SUITE INVALID: no .spec modules were discovered")
	_PrintDivider()
	print("")
end

local function _PrintFilteredSuiteWarning()
	print("")
	_PrintDivider()
	warn("TEST SUITE INVALID: no discovered .spec modules matched SPEC_NAME_FILTERS")
	_PrintDivider()
	print("")
end

local function _PrintSuiteSummary(testResults: TTestResults)
	print("")
	_PrintDivider()
	if testResults.failureCount == 0 then
		print("TEST SUITE COMPLETED")
	else
		print("TEST FAILURES DETECTED")
	end
	print(("Passed: %d"):format(testResults.successCount))
	print(("Failed: %d"):format(testResults.failureCount))
	_PrintDivider()
	print("")
end

local function _IsSpecModule(moduleScript: ModuleScript): boolean
	local moduleName = moduleScript.Name
	return string.match(moduleName, "%.spec$") ~= nil or string.match(moduleName, "%.spec%.lua$") ~= nil
end

local function _GetSpecFilterName(moduleScript: ModuleScript): string
	local moduleName = moduleScript.Name
	local withoutLuaSuffix = string.gsub(moduleName, "%.lua$", "")
	local withoutSpecSuffix = string.gsub(withoutLuaSuffix, "%.spec$", "")
	return withoutSpecSuffix
end

local function _MatchesSpecNameFilter(moduleScript: ModuleScript): boolean
	if #SPEC_NAME_FILTERS == 0 then
		return true
	end

	local filterName = _GetSpecFilterName(moduleScript)

	for _, allowedName in ipairs(SPEC_NAME_FILTERS) do
		if filterName == allowedName then
			return true
		end
	end

	return false
end

local function _CollectSpecModules(): { ModuleScript }
	local specModules = {}

	for _, container in ipairs(TEST_CONTAINERS) do
		for _, descendant in ipairs(container:GetDescendants()) do
			if descendant:IsA("ModuleScript") and _IsSpecModule(descendant) and _MatchesSpecNameFilter(descendant) then
				table.insert(specModules, descendant)
			end
		end
	end

	table.sort(specModules, function(left: ModuleScript, right: ModuleScript): boolean
		return left:GetFullName() < right:GetFullName()
	end)

	return specModules
end

local function _RunDiscoveredTests()
	local testLocations = _CollectSpecModules()

	if #testLocations == 0 then
		if #SPEC_NAME_FILTERS == 0 then
			_PrintEmptySuiteWarning()
		else
			_PrintFilteredSuiteWarning()
		end
		return
	end

	_PrintSuiteHeader(#testLocations)

	local runSucceeded, testResultsOrError = pcall(function(): TTestResults
		return TestEZ.TestBootstrap:run(testLocations, REPORTER)
	end)

	if not runSucceeded then
		warn(("TEST HARNESS FAILED: %s"):format(tostring(testResultsOrError)))
		return
	end

	_PrintSuiteSummary(testResultsOrError :: TTestResults)
end

if not RUN_TESTS then
	return
end

Knit.OnStart()
	:andThen(function()
		_RunDiscoveredTests()
	end)
	:catch(function(runError)
		warn(("TEST HARNESS FAILED BEFORE EXECUTION: %s"):format(tostring(runError)))
	end)
