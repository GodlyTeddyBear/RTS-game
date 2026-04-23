--!strict

--[=[
    @class ChildArraySpec
    Shared specification that validates composite-node child arrays used by BehaviorSystem symbolic definitions.
    @server
    @client
]=]

local ChildArraySpec = {}

--[=[
    Validates that a table is a dense 1-based child array with at least one entry.
    @within ChildArraySpec
    @param children any -- Candidate child collection
    @return boolean -- Whether the child collection is valid
    @return string? -- Validation failure reason when invalid
]=]
function ChildArraySpec.Validate(children: any): (boolean, string?)
	if type(children) ~= "table" then
		return false, "must contain a child array"
	end

	if next(children) == nil then
		return false, "must contain at least one child"
	end

	if children[1] == nil then
		return false, "must start at index 1"
	end

	local childCount = 0
	local maxIndex = 0
	for key in pairs(children) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false, ("contains non-array key '%s'"):format(tostring(key))
		end

		local numericKey = key :: number
		childCount += 1
		if numericKey > maxIndex then
			maxIndex = numericKey
		end
	end

	if maxIndex ~= childCount then
		return false, "has a sparse child array"
	end

	return true, nil
end

return table.freeze(ChildArraySpec)
