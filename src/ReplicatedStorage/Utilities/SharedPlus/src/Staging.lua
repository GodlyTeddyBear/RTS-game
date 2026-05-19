--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Utilities.TableUtil)

local Staging = {}

local function _AssertContiguousArray(values: { any }, context: string)
	local expectedIndex = 1
	for index in ipairs(values) do
		assert(index == expectedIndex, `{context} arrays must be contiguous`)
		expectedIndex += 1
	end

	for key in pairs(values) do
		assert(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key < expectedIndex,
			`{context} only accepts array-like tables`
		)
	end
end

function Staging.AssertFlatArray(values: { any }, context: string)
	assert(type(values) == "table", `{context} requires a table`)
	_AssertContiguousArray(values, context)

	for _, value in ipairs(values) do
		assert(type(value) ~= "table", `{context} only accepts flat arrays`)
	end
end

function Staging.FlattenNestedArray(recyclerHandle: any, values: { any }, context: string): { any }
	assert(type(values) == "table", `{context} requires a table`)
	assert(recyclerHandle ~= nil, "SharedPlus flattening requires a recycler handle")

	local stack = recyclerHandle:AcquireArray()
	local depthStack = recyclerHandle:AcquireArray()
	local didResolve, resultOrError = xpcall(function()
		stack[1] = values
		depthStack[1] = 1

		local maxDepth = 1
		local stackCount = 1

		while stackCount > 0 do
			local current = stack[stackCount]
			local currentDepth = depthStack[stackCount]
			stack[stackCount] = nil
			depthStack[stackCount] = nil
			stackCount -= 1

			_AssertContiguousArray(current, context)

			for _, value in ipairs(current) do
				if type(value) == "table" then
					stackCount += 1
					stack[stackCount] = value
					depthStack[stackCount] = currentDepth + 1
					if currentDepth + 1 > maxDepth then
						maxDepth = currentDepth + 1
					end
				end
			end
		end

		if maxDepth <= 1 then
			return values
		end

		return TableUtil.Flat(values, maxDepth)
	end, function(errorMessage)
		return tostring(errorMessage)
	end)

	local didReleaseStack, releaseStackError = recyclerHandle:ReleaseArray(stack)
	assert(didReleaseStack, releaseStackError)
	local didReleaseDepthStack, releaseDepthStackError = recyclerHandle:ReleaseArray(depthStack)
	assert(didReleaseDepthStack, releaseDepthStackError)

	if not didResolve then
		error(resultOrError, 2)
	end

	return resultOrError
end

return table.freeze(Staging)
