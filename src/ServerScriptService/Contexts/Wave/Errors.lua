--!strict

--[=[
	@class Errors
	Defines the centralized Wave context error messages.
	@server
]=]
local Errors = {
	--[=[
		@prop UNKNOWN_WAVE string
		@within Errors
		Returned when a scripted or endless wave definition cannot be found.
	]=]
	UNKNOWN_WAVE = "WaveContext: no wave definition found for wave number",
	--[=[
		@prop WAVE_ALREADY_ACTIVE string
		@within Errors
		Returned when a new wave starts before the prior one is cleaned up.
	]=]
	WAVE_ALREADY_ACTIVE = "WaveContext: received WaveStarted while wave already active",
	--[=[
		@prop INVALID_ENEMY_DIED string
		@within Errors
		Returned when a death event arrives without an active wave session.
	]=]
	INVALID_ENEMY_DIED = "WaveContext: EnemyDied received but no wave is active",
	--[=[
		@prop NO_SPAWN_AREAS string
		@within Errors
		Returned when the world exposes no spawn areas for the scheduler.
	]=]
	NO_SPAWN_AREAS = "WaveContext: no spawn areas available - WorldContext returned empty",
	--[=[
		@prop INVALID_WAVE_NUMBER string
		@within Errors
		Returned when a caller passes a non-positive wave number.
	]=]
	INVALID_WAVE_NUMBER = "WaveContext: wave number must be greater than zero",
	--[=[
		@prop DISALLOWED_ENEMY_ROLE string
		@within Errors
		Returned when a wave composition includes a role not allowed for the active phase.
	]=]
	DISALLOWED_ENEMY_ROLE = "WaveContext: wave composition contains a disallowed enemy role",
	--[=[
		@prop NOTIFY_WAVE_CLEARED_FAILED string
		@within Errors
		Returned when `RunContext` rejects the wave-cleared notification.
	]=]
	NOTIFY_WAVE_CLEARED_FAILED = "WaveContext: RunContext rejected NotifyWaveCleared call",
	--[=[
		@prop MISSING_RUN_CONTEXT string
		@within Errors
		Returned when `RunContext` is unavailable during event handling.
	]=]
	MISSING_RUN_CONTEXT = "WaveContext: RunContext dependency is unavailable",
	--[=[
		@prop MISSING_WORLD_CONTEXT string
		@within Errors
		Returned when `WorldContext` is unavailable during startup.
	]=]
	MISSING_WORLD_CONTEXT = "WaveContext: WorldContext dependency is unavailable",
	--[=[
		@prop TEARDOWN_FAILED string
		@within Errors
		Returned when BaseContext teardown reports a failure.
	]=]
	TEARDOWN_FAILED = "WaveContext: BaseContext teardown failed",
}

return table.freeze(Errors)
