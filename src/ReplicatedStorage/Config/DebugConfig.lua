--!strict

--[[
	Master Debug Configuration

	Global master switch for all debug logging across the entire codebase.
	Set ENABLED to false to disable ALL debug logging regardless of context-specific settings.
]]

local MILLISECOND = 1 / 1000
local MICROSECOND = 1 / 1000000

return table.freeze({
	ENABLED = true, -- Master switch for ALL debug logging
	RESET_DATA_ON_JOIN = false, -- Wipe player data to template defaults on every join (testing only)
	MILLISECOND = MILLISECOND, -- One millisecond expressed in seconds for time-based debug config values
	MICROSECOND = MICROSECOND, -- One microsecond expressed in seconds for time-based debug config values
	SCHEDULER_INTERVAL = 1 / 60, -- Seconds between server scheduler ticks (testing only)
	COMBAT_TICK_TIME_BUDGET_SECONDS = 4 * MILLISECOND, -- Max wall-clock seconds one combat session frame may spend before spillback (testing only)
	COMBAT_MOVEMENT_PIPELINE_STAGE_RESERVE_SECONDS = 0.5 * MILLISECOND, -- Amount needed left to continue, Reserve budget that makes the movement pipeline defer later stages to the next tick (testing only)
	COMBAT_RUNTIME_ESTIMATE_WARN_MILLISECONDS_PER_TICK = 4 * MILLISECOND, -- Warn when one combat tick budget exceeds the recommended combat-script budget per tick
	COMBAT_RUNTIME_ESTIMATE_WARN_MILLISECONDS_PER_SECOND = 240 * MILLISECOND, -- Warn when estimated combat runtime envelope exceeds the recommended sustained combat-script budget per second
	COMBAT_RUNTIME_ESTIMATE_WARN_TICKS_PER_SECOND = 120, -- Warn when combat scheduler tick frequency exceeds this many ticks per second
	COMBAT_SCHEDULER_PROFILING = true, -- Enables CombatContext scheduler profiling scopes (testing only)
	AI_RUNTIME_FRAME_PROFILING = true, -- Enables AI.Runtime.RunFrame DebugPlus scopes (testing only)
	COMBAT_MOVEMENT_PROFILING = true, -- Enables MovementService profiling scopes (testing only)
	PARALLEL_RUNNER_PROFILING = true, -- Enables ParallelRunner managed-job dispatch profiling scopes (testing only)
	PARALLEL_QUERY_PROFILING = true, -- Enables ParallelQuery DebugPlus scopes on coarse runner and managed-job paths (testing only)
	AI_RUNTIME_PROFILING = false, -- Enables shared AI runtime phase timing logs (testing only)
	AI_RUNTIME_PROFILING_LOG_INTERVAL_SECONDS = 1, -- Minimum seconds between AI runtime profile logs
})
