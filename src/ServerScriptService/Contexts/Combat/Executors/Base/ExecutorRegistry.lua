--!strict

--[=[
	@class ExecutorRegistry
	Registry that maps action ID strings to executor instances.

	All executors are registered at `CombatContext:KnitInit()` and looked up
	by `ProcessCombatTick` when executing NPC decisions. Supports all action types:
	movement (Chase, Idle, Flee), attacks (Melee, Ranged, Sword, etc.), and custom executors.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)

type IExecutor = ExecutorTypes.IExecutor

local ExecutorRegistry = {}
ExecutorRegistry.__index = ExecutorRegistry

export type TExecutorRegistry = typeof(setmetatable({} :: { _Executors: { [string]: IExecutor } }, ExecutorRegistry))

function ExecutorRegistry.new(): TExecutorRegistry
	local self = setmetatable({}, ExecutorRegistry)
	self._Executors = {} :: { [string]: IExecutor }
	return self
end

--[=[
	Register an executor under an action ID.
	@within ExecutorRegistry
	@param actionId string -- Unique identifier for the action (e.g., "Chase", "MeleeAttack")
	@param executor IExecutor -- Executor instance
	@error "Action ID must be a non-empty string"
	@error "Executor instance must not be nil"
	@error "Executor instance must have a Config"
]=]
function ExecutorRegistry:Register(actionId: string, executor: IExecutor)
	assert(type(actionId) == "string" and #actionId > 0, "Action ID must be a non-empty string")
	assert(executor, "Executor instance must not be nil")
	assert(executor.Config, "Executor instance must have a Config")
	self._Executors[actionId] = executor
end

--[=[
	Get an executor by action ID.
	@within ExecutorRegistry
	@param actionId string
	@return IExecutor? -- Executor instance or nil if not found
]=]
function ExecutorRegistry:Get(actionId: string): IExecutor?
	return self._Executors[actionId]
end

return ExecutorRegistry
