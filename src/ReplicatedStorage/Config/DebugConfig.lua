--!strict

--[[
	Master Debug Configuration

	Global master switch for all debug logging across the entire codebase.
	Set ENABLED to false to disable ALL debug logging regardless of context-specific settings.
]]

return table.freeze({
	ENABLED = true, -- Master switch for ALL debug logging
	RESET_DATA_ON_JOIN = false, -- Wipe player data to template defaults on every join (testing only)
	SCHEDULER_INTERVAL = 10 / 60, -- Seconds between server scheduler ticks (testing only)
	AI_RUNTIME_PROFILING = false, -- Enables shared AI runtime phase timing logs (testing only)
	AI_RUNTIME_PROFILING_LOG_INTERVAL_SECONDS = 1, -- Minimum seconds between AI runtime profile logs
})
