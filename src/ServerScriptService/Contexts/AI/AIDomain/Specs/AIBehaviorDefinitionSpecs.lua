--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TBehaviorDefinitionCandidate = {
	Node: any,
	Children: any,
	LeafName: any,
	EvaluationRegistered: boolean,
	ActionRegistered: boolean,
	Depth: number,
	MaxDepth: number,
}

local HasSupportedNodeType =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
		local nodeType = type(candidate.Node)
		return nodeType == "string" or nodeType == "table"
	end)

local HasNonEmptyLeaf =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
		return type(candidate.LeafName) == "string" and candidate.LeafName ~= ""
	end)

local HasCompositeKind =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
		local node = candidate.Node
		if type(node) ~= "table" then
			return false
		end

		return node.Sequence ~= nil or node.Priority ~= nil
	end)

local HasSingleCompositeKind =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
		local node = candidate.Node
		if type(node) ~= "table" then
			return false
		end

		return not (node.Sequence ~= nil and node.Priority ~= nil)
	end)

local HasSupportedCompositeKeys =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
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
	end)

local HasChildArray =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
		return type(candidate.Children) == "table"
	end)

local HasChildEntries =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
		return type(candidate.Children) == "table" and next(candidate.Children) ~= nil
	end)

local StartsAtIndexOne =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
		return type(candidate.Children) == "table" and candidate.Children[1] ~= nil
	end)

local HasDenseArrayKeys =
	Spec.new("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, function(candidate: TBehaviorDefinitionCandidate)
		local children = candidate.Children
		if type(children) ~= "table" then
			return false
		end

		local childCount = 0
		local maxIndex = 0
		for key in pairs(children) do
			if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
				return false
			end

			childCount += 1
			if key > maxIndex then
				maxIndex = key
			end
		end

		return maxIndex == childCount
	end)

local HasRegisteredLeaf =
	Spec.new("UnknownBehaviorLeaf", Errors.UNKNOWN_BEHAVIOR_LEAF, function(candidate: TBehaviorDefinitionCandidate)
		return candidate.EvaluationRegistered or candidate.ActionRegistered
	end)

local HasUnambiguousLeaf =
	Spec.new("AmbiguousBehaviorLeaf", Errors.AMBIGUOUS_BEHAVIOR_LEAF, function(candidate: TBehaviorDefinitionCandidate)
		return not (candidate.EvaluationRegistered and candidate.ActionRegistered)
	end)

local IsWithinMaxDepth =
	Spec.new("BehaviorDefinitionTooDeep", Errors.BEHAVIOR_DEFINITION_TOO_DEEP, function(candidate: TBehaviorDefinitionCandidate)
		return candidate.Depth <= candidate.MaxDepth
	end)

return table.freeze({
	HasSupportedNodeType = HasSupportedNodeType,
	HasNonEmptyLeaf = HasNonEmptyLeaf,
	HasCompositeKind = HasCompositeKind,
	HasSingleCompositeKind = HasSingleCompositeKind,
	HasSupportedCompositeKeys = HasSupportedCompositeKeys,
	HasChildArray = HasChildArray,
	HasChildEntries = HasChildEntries,
	StartsAtIndexOne = StartsAtIndexOne,
	HasDenseArrayKeys = HasDenseArrayKeys,
	HasRegisteredLeaf = HasRegisteredLeaf,
	HasUnambiguousLeaf = HasUnambiguousLeaf,
	HasDenseNonEmptyChildArray = HasChildArray:And(HasChildEntries):And(StartsAtIndexOne):And(HasDenseArrayKeys),
	HasKnownLeaf = HasRegisteredLeaf:And(HasUnambiguousLeaf),
	IsWithinMaxDepth = IsWithinMaxDepth,
})
