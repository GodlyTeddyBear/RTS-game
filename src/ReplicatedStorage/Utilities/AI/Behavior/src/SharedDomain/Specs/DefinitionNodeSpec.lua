--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TDefinitionNodeCandidate = {
	Node: any,
}

local HasSupportedNodeType = Spec.new(
	"InvalidDefinitionNode",
	"must be a string or table",
	function(candidate: TDefinitionNodeCandidate): boolean
		local nodeType = type(candidate.Node)
		return nodeType == "string" or nodeType == "table"
	end
)

local HasCompositeTable = Spec.new(
	"InvalidCompositeNode",
	"must be a table",
	function(candidate: TDefinitionNodeCandidate): boolean
		return type(candidate.Node) == "table"
	end
)

local HasCompositeKind = Spec.new(
	"InvalidCompositeNode",
	"must declare Sequence or Priority",
	function(candidate: TDefinitionNodeCandidate): boolean
		local node = candidate.Node
		if type(node) ~= "table" then
			return false
		end

		return node.Sequence ~= nil or node.Priority ~= nil
	end
)

local HasSingleCompositeKind = Spec.new(
	"InvalidCompositeNode",
	"cannot declare both Sequence and Priority",
	function(candidate: TDefinitionNodeCandidate): boolean
		local node = candidate.Node
		if type(node) ~= "table" then
			return true
		end

		return not (node.Sequence ~= nil and node.Priority ~= nil)
	end
)

local HasSupportedCompositeKeys = Spec.new(
	"InvalidCompositeNode",
	"contains unsupported keys",
	function(candidate: TDefinitionNodeCandidate): boolean
		local node = candidate.Node
		if type(node) ~= "table" then
			return false
		end

		for key in pairs(node) do
			if key ~= "Sequence" and key ~= "Priority" then
				return false
			end
		end

		return true
	end
)

local HasSequenceNode = Spec.new(
	"InvalidSequenceNode",
	"is not a valid Sequence node",
	function(candidate: TDefinitionNodeCandidate): boolean
		local node = candidate.Node
		return type(node) == "table" and type(node.Sequence) == "table"
	end
)

local HasPriorityNode = Spec.new(
	"InvalidPriorityNode",
	"is not a valid Priority node",
	function(candidate: TDefinitionNodeCandidate): boolean
		local node = candidate.Node
		return type(node) == "table" and type(node.Priority) == "table"
	end
)

return table.freeze({
	HasValidNodeShape = HasSupportedNodeType,
	HasValidCompositeShape = HasCompositeTable
		:And(HasCompositeKind)
		:And(HasSingleCompositeKind)
		:And(HasSupportedCompositeKeys),
	HasSequenceNode = HasSequenceNode,
	HasPriorityNode = HasPriorityNode,
})
