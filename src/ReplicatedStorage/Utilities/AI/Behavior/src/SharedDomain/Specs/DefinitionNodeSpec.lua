--!strict

--[=[
    @class DefinitionNodeSpec
    Shared specification that validates symbolic definition node shapes before BehaviorSystem compilation.
    @server
    @client
]=]

local DefinitionNodeSpec = {}

--[=[
    Validates the outer shape of a symbolic behavior node.
    @within DefinitionNodeSpec
    @param node any -- Candidate node
    @return boolean -- Whether the node is a supported symbolic shape
    @return string? -- Validation failure reason when invalid
]=]
function DefinitionNodeSpec.ValidateNodeShape(node: any): (boolean, string?)
	local nodeType = type(node)
	if nodeType ~= "string" and nodeType ~= "table" then
		return false, "must be a string or table"
	end

	return true, nil
end

--[=[
    Validates the shape of a composite symbolic node.
    @within DefinitionNodeSpec
    @param node any -- Candidate node
    @return boolean -- Whether the node declares exactly one composite field
    @return string? -- Validation failure reason when invalid
]=]
function DefinitionNodeSpec.ValidateCompositeShape(node: any): (boolean, string?)
	if type(node) ~= "table" then
		return false, "must be a table"
	end

	local hasSequence = node.Sequence ~= nil
	local hasPriority = node.Priority ~= nil
	if not hasSequence and not hasPriority then
		return false, "must declare Sequence or Priority"
	end

	if hasSequence and hasPriority then
		return false, "cannot declare both Sequence and Priority"
	end

	for key in pairs(node) do
		if key ~= "Sequence" and key ~= "Priority" then
			return false, ("contains unsupported key '%s'"):format(tostring(key))
		end
	end

	return true, nil
end

return table.freeze(DefinitionNodeSpec)
