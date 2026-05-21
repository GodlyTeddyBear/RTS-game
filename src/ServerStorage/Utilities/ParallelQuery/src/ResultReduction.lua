--!strict

local Types = require(script.Parent.Types)

type TReductionSummary = Types.TReductionSummary

local ResultReduction = {}

local function _CreateSummary(rowCount: number): TReductionSummary
	return {
		RowCount = rowCount,
		ReducedCount = 0,
		SkippedCount = 0,
		GroupCount = 0,
	}
end

function ResultReduction.BuildLookupMap(
	rows: { [number]: { [string]: any } },
	resolveKey: (row: { [string]: any }, rowIndex: number) -> any?,
	resolveValue: ((row: { [string]: any }, rowIndex: number) -> any?)?
): ({ [any]: any }, TReductionSummary)
	local lookupMap = {}
	local summary = _CreateSummary(#rows)

	for rowIndex, row in ipairs(rows) do
		local key = resolveKey(row, rowIndex)
		if key == nil then
			summary.SkippedCount += 1
			continue
		end

		lookupMap[key] = if resolveValue ~= nil then resolveValue(row, rowIndex) else row
		summary.ReducedCount += 1
	end

	summary.GroupCount = 0
	return lookupMap, summary
end

function ResultReduction.GroupRows(
	rows: { [number]: { [string]: any } },
	resolveKey: (row: { [string]: any }, rowIndex: number) -> any?
): ({ [any]: { [number]: { [string]: any } } }, TReductionSummary)
	local groupedRows = {}
	local summary = _CreateSummary(#rows)

	for rowIndex, row in ipairs(rows) do
		local key = resolveKey(row, rowIndex)
		if key == nil then
			summary.SkippedCount += 1
			continue
		end

		local bucket = groupedRows[key]
		if bucket == nil then
			bucket = {}
			groupedRows[key] = bucket
			summary.GroupCount += 1
		end

		table.insert(bucket, row)
		summary.ReducedCount += 1
	end

	return groupedRows, summary
end

function ResultReduction.Reduce(
	rows: { [number]: { [string]: any } },
	initialState: any,
	reducer: (state: any, row: { [string]: any }, rowIndex: number) -> boolean?
): (any, TReductionSummary)
	local state = initialState
	local summary = _CreateSummary(#rows)

	for rowIndex, row in ipairs(rows) do
		local reduced = reducer(state, row, rowIndex)
		if reduced == false then
			summary.SkippedCount += 1
			continue
		end

		summary.ReducedCount += 1
	end

	return state, summary
end

function ResultReduction.ReduceIndexedPairs(
	rows: { [number]: { [string]: any } },
	firstIndexFieldName: string,
	secondIndexFieldName: string,
	maxIndex: number?,
	initialState: any,
	reducer: (state: any, row: { [string]: any }, firstIndex: number, secondIndex: number, rowIndex: number) -> boolean?
): (any, TReductionSummary)
	local state = initialState
	local summary = _CreateSummary(#rows)

	for rowIndex, row in ipairs(rows) do
		local firstIndex = row[firstIndexFieldName]
		local secondIndex = row[secondIndexFieldName]
		if type(firstIndex) ~= "number" or firstIndex % 1 ~= 0 or firstIndex < 1 then
			summary.SkippedCount += 1
			continue
		end
		if type(secondIndex) ~= "number" or secondIndex % 1 ~= 0 or secondIndex < 1 then
			summary.SkippedCount += 1
			continue
		end
		if maxIndex ~= nil and (firstIndex > maxIndex or secondIndex > maxIndex) then
			summary.SkippedCount += 1
			continue
		end

		local reduced = reducer(state, row, firstIndex, secondIndex, rowIndex)
		if reduced == false then
			summary.SkippedCount += 1
			continue
		end

		summary.ReducedCount += 1
	end

	return state, summary
end

function ResultReduction.AccumulateVector2ByKey(
	rows: { [number]: { [string]: any } },
	keyFieldName: string,
	xFieldName: string,
	yFieldName: string
): ({ [any]: Vector2 }, TReductionSummary)
	local accumulated = {}
	local summary = _CreateSummary(#rows)

	for _, row in ipairs(rows) do
		local key = row[keyFieldName]
		local x = row[xFieldName]
		local y = row[yFieldName]
		if key == nil or type(x) ~= "number" or type(y) ~= "number" then
			summary.SkippedCount += 1
			continue
		end

		accumulated[key] = (accumulated[key] or Vector2.zero) + Vector2.new(x, y)
		summary.ReducedCount += 1
	end

	summary.GroupCount = 0
	for _ in accumulated do
		summary.GroupCount += 1
	end

	return accumulated, summary
end

function ResultReduction.AccumulateIndexedPairVector2(
	rows: { [number]: { [string]: any } },
	firstIndexFieldName: string,
	secondIndexFieldName: string,
	firstXFieldName: string,
	firstYFieldName: string,
	secondXFieldName: string,
	secondYFieldName: string,
	maxIndex: number?
): ({ [number]: Vector2 }, TReductionSummary)
	local accumulated = {}
	local summary = _CreateSummary(#rows)

	for _, row in ipairs(rows) do
		local firstIndex = row[firstIndexFieldName]
		local secondIndex = row[secondIndexFieldName]
		local firstX = row[firstXFieldName]
		local firstY = row[firstYFieldName]
		local secondX = row[secondXFieldName]
		local secondY = row[secondYFieldName]

		local isInvalidIndex = type(firstIndex) ~= "number"
			or firstIndex % 1 ~= 0
			or firstIndex < 1
			or type(secondIndex) ~= "number"
			or secondIndex % 1 ~= 0
			or secondIndex < 1
			or (maxIndex ~= nil and (firstIndex > maxIndex or secondIndex > maxIndex))

		if isInvalidIndex
			or type(firstX) ~= "number"
			or type(firstY) ~= "number"
			or type(secondX) ~= "number"
			or type(secondY) ~= "number"
		then
			summary.SkippedCount += 1
			continue
		end

		accumulated[firstIndex] = (accumulated[firstIndex] or Vector2.zero) + Vector2.new(firstX, firstY)
		accumulated[secondIndex] = (accumulated[secondIndex] or Vector2.zero) + Vector2.new(secondX, secondY)
		summary.ReducedCount += 1
	end

	for _ in accumulated do
		summary.GroupCount += 1
	end

	return accumulated, summary
end

return table.freeze(ResultReduction)
