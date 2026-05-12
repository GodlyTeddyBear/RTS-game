--!strict

local Types = require(script.Parent.Types)

type TCleanupFailure = Types.TCleanupFailure
type TCleanupMethod = Types.TCleanupMethod
type TCleanupReport = Types.TCleanupReport

export type TMutableCleanupReport = {
	Success: boolean,
	FailureCount: number,
	ResourceCountCleaned: number,
	ScopeCountCleaned: number,
	Failures: { TCleanupFailure },
	CleanedChildren: { string },
}

local CleanupReport = {}

function CleanupReport.new(): TMutableCleanupReport
	return {
		Success = true,
		FailureCount = 0,
		ResourceCountCleaned = 0,
		ScopeCountCleaned = 0,
		Failures = {},
		CleanedChildren = {},
	}
end

function CleanupReport.RecordFailure(
	report: TMutableCleanupReport,
	label: string?,
	key: any?,
	resource: any?,
	cleanupMethod: TCleanupMethod?,
	errorMessage: string,
	scopeName: string?,
	scopePath: string?
)
	report.Success = false
	report.FailureCount += 1

	table.insert(report.Failures, {
		Label = label,
		Key = key,
		Resource = resource,
		ResourceType = if resource ~= nil then typeof(resource) else nil,
		CleanupMethod = cleanupMethod,
		ErrorMessage = errorMessage,
		ScopeName = scopeName,
		ScopePath = scopePath,
	})
end

function CleanupReport.RecordSuccess(report: TMutableCleanupReport)
	report.ResourceCountCleaned += 1
end

function CleanupReport.RecordChild(report: TMutableCleanupReport, childName: string)
	table.insert(report.CleanedChildren, childName)
	report.ScopeCountCleaned += 1
end

function CleanupReport.Merge(target: TMutableCleanupReport, source: TCleanupReport)
	if not source.Success then
		target.Success = false
		target.FailureCount += source.FailureCount
	end

	target.ResourceCountCleaned += source.ResourceCountCleaned
	target.ScopeCountCleaned += source.ScopeCountCleaned

	for _, failure in ipairs(source.Failures) do
		table.insert(target.Failures, failure)
	end

	local cleanedChildren = source.CleanedChildren
	if cleanedChildren == nil then
		return
	end

	for _, childName in ipairs(cleanedChildren) do
		table.insert(target.CleanedChildren, childName)
	end
end

function CleanupReport.Finalize(report: TMutableCleanupReport): TCleanupReport
	local finalizedChildren = if #report.CleanedChildren > 0 then table.freeze(table.clone(report.CleanedChildren)) else nil

	return table.freeze({
		Success = report.Success,
		FailureCount = report.FailureCount,
		ResourceCountCleaned = report.ResourceCountCleaned,
		ScopeCountCleaned = report.ScopeCountCleaned,
		Failures = table.freeze(table.clone(report.Failures)),
		CleanedChildren = finalizedChildren,
	})
end

return table.freeze(CleanupReport)
