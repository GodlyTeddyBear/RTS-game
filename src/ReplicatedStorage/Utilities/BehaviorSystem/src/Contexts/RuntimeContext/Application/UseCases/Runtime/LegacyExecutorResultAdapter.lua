--!strict

local ExecutorDefectTypes = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.ExecutorDefectTypes)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

type TStartActionResult = Types.TStartActionResult
type TTickActionResult = Types.TTickActionResult
type TCancelActionResult = Types.TCancelActionResult
type TTryStartActionResult = Types.TTryStartActionResult
type TTryTickActionResult = Types.TTryTickActionResult
type TTryCancelActionResult = Types.TTryCancelActionResult

local LegacyExecutorResultAdapter = {}

function LegacyExecutorResultAdapter.Start(
	result: TTryStartActionResult,
	pendingActionId: string?,
	currentActionId: string?
): TStartActionResult
	if result.success then
		return result.value
	end

	return {
		Status = "FailedToStart",
		ActionId = pendingActionId,
		ReplacedActionId = currentActionId,
		FailureReason = result.message,
	}
end

function LegacyExecutorResultAdapter.Tick(result: TTryTickActionResult, currentActionId: string?): TTickActionResult
	if result.success then
		return result.value
	end

	local status = if result.type == ExecutorDefectTypes.ExecutorCompleteDefect then "Success" else "Fail"
	return {
		Status = status,
		ActionId = currentActionId,
	}
end

function LegacyExecutorResultAdapter.Cancel(result: TTryCancelActionResult, currentActionId: string?): TCancelActionResult
	if result.success then
		return result.value
	end

	return {
		Status = "Cancelled",
		ActionId = currentActionId,
	}
end

return table.freeze(LegacyExecutorResultAdapter)
