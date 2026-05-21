--!strict

local Types = require(script.Parent.Types)

type TRowApplicationResult = Types.TRowApplicationResult
type TRowFieldValidationResult = Types.TRowFieldValidationResult

type TApplyRowsConfig = {
	Rows: { [number]: { [string]: any } },
	ValidateRow: ((row: { [string]: any }, rowIndex: number) -> (boolean | TRowFieldValidationResult))?,
	ResolveTarget: ((row: { [string]: any }, rowIndex: number) -> any?)?,
	ApplyRow: (resolvedTarget: any, row: { [string]: any }, rowIndex: number) -> boolean?,
}

local ResultApplication = {}

local function _BuildSummary(rowCount: number): TRowApplicationResult
	return {
		RowCount = rowCount,
		AppliedCount = 0,
		InvalidRowCount = 0,
		UnresolvedCount = 0,
		SkippedCount = 0,
	}
end

local function _IsValidationAccepted(result: boolean | TRowFieldValidationResult): boolean
	if type(result) == "boolean" then
		return result
	end
	return result.IsValid
end

function ResultApplication.ResolveIndexedValue(
	row: { [string]: any },
	indexFieldName: string,
	valuesByIndex: { [number]: any }
): (any?, number?)
	local index = row[indexFieldName]
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 then
		return nil, nil
	end

	return valuesByIndex[index], index
end

function ResultApplication.ResolveIndexedPair(
	row: { [string]: any },
	firstIndexFieldName: string,
	secondIndexFieldName: string,
	valuesByIndex: { [number]: any }
): (any?, any?, number?, number?)
	local firstValue, firstIndex = ResultApplication.ResolveIndexedValue(row, firstIndexFieldName, valuesByIndex)
	if firstValue == nil or firstIndex == nil then
		return nil, nil, nil, nil
	end

	local secondValue, secondIndex = ResultApplication.ResolveIndexedValue(row, secondIndexFieldName, valuesByIndex)
	if secondValue == nil or secondIndex == nil then
		return nil, nil, nil, nil
	end

	return firstValue, secondValue, firstIndex, secondIndex
end

function ResultApplication.ApplyRows(config: TApplyRowsConfig): TRowApplicationResult
	assert(type(config) == "table", "ParallelQuery.ResultApplication.ApplyRows requires a config table")
	assert(type(config.Rows) == "table", "ParallelQuery.ResultApplication.ApplyRows requires Rows")
	assert(type(config.ApplyRow) == "function", "ParallelQuery.ResultApplication.ApplyRows requires ApplyRow")

	local summary = _BuildSummary(#config.Rows)

	for rowIndex, row in ipairs(config.Rows) do
		if config.ValidateRow ~= nil then
			local validationResult = config.ValidateRow(row, rowIndex)
			if not _IsValidationAccepted(validationResult) then
				summary.InvalidRowCount += 1
				continue
			end
		end

		local resolvedTarget = row
		if config.ResolveTarget ~= nil then
			resolvedTarget = config.ResolveTarget(row, rowIndex)
			if resolvedTarget == nil then
				summary.UnresolvedCount += 1
				continue
			end
		end

		local applied = config.ApplyRow(resolvedTarget, row, rowIndex)
		if applied == false then
			summary.SkippedCount += 1
			continue
		end

		summary.AppliedCount += 1
	end

	return summary
end

return table.freeze(ResultApplication)
