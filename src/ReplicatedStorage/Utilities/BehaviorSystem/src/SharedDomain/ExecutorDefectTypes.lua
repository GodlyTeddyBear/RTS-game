--!strict

local ExecutorDefectTypes = table.freeze({
	ExecutorStartDefect = "ExecutorStartDefect",
	ExecutorTickDefect = "ExecutorTickDefect",
	ExecutorCancelDefect = "ExecutorCancelDefect",
	ExecutorCompleteDefect = "ExecutorCompleteDefect",
	ExecutorDeathDefect = "ExecutorDeathDefect",
})

return ExecutorDefectTypes
