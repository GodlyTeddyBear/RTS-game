--[=[
	@class DictDiff
	Utility for computing set differences between tables.
	@server
	@client
]=]

local module = {}

-- Checks whether a value exists in an indexed table by reference equality.
local function find(a, tbl)
	for _, a_ in ipairs(tbl) do
		if a_ == a then return true end
	end
end

--[=[
	@function difference
	@within DictDiff
	Returns all elements from table `a` that do not exist in table `b` (by reference equality).
	Used to detect when parts stop touching the hitbox.
	@param a { T } -- The reference table
	@param b { T }? -- The comparison table (nil is treated as empty)
	@return { T } -- Elements in `a` but not in `b`
]=]
function module.difference(a, b)
	local ret = {}
	for _, v in ipairs(a) do
		-- Add to result if element is not found in comparison table
		if not find(v, b) then table.insert(ret, v) end
	end

	return ret
end

return module