local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TestEZ = require(ReplicatedStorage.Packages.Testez)

--[[
Global Test Runner

Discovers and runs all tests in the Testing directory:
- Inventory domain service tests
- Future: Character domain service tests
- Future: Other context tests

Modify the TESTING flag below to enable/disable tests.
]]

local TESTING = false
if not TESTING then
	return
end

print("\n" .. string.rep("═", 70))
print("GLOBAL TEST SUITE")
print("Running all available tests")
print(string.rep("═", 70) .. "\n")

-- Test locations to discover and run
local testLocations = {
	ServerScriptService.Testing.Inventory,
	ServerScriptService.Testing.Inventory.Sync,
}

local reporter = TestEZ.Reporters.TextReporter

local testResults = TestEZ.TestBootstrap:run(testLocations, reporter)

-- Summary
print("\n" .. string.rep("═", 70))
if testResults.successCount > 0 or testResults.failureCount == 0 then
	print("✅ TEST SUITE COMPLETED")
else
	print("❌ TEST FAILURES DETECTED")
end
print(string.rep("═", 70) .. "\n")