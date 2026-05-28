--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local AIBehaviorDefinitionSpecs = require(script.Parent.Parent.Specs.AIBehaviorDefinitionSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local DEFAULT_MAX_DEFINITION_DEPTH = 16

local AIBehaviorDefinitionPolicy = {}
AIBehaviorDefinitionPolicy.__index = AIBehaviorDefinitionPolicy

function AIBehaviorDefinitionPolicy.new(evaluationRegistry: any?, actionRegistry: any?, maxDepth: number?)
	local self = setmetatable({}, AIBehaviorDefinitionPolicy)
	self._evaluationRegistry = evaluationRegistry
	self._actionRegistry = actionRegistry
	self._maxDepth = maxDepth or DEFAULT_MAX_DEFINITION_DEPTH
	return self
end

function AIBehaviorDefinitionPolicy:Init(registry: any, _name: string)
	if self._evaluationRegistry == nil then
		self._evaluationRegistry = registry:Get("AIEvaluationRegistry")
	end
	if self._actionRegistry == nil then
		self._actionRegistry = registry:Get("AIActionDefinitionRegistry")
	end
end

function AIBehaviorDefinitionPolicy:Check(definition: any): Result.Result<any>
	if self._evaluationRegistry == nil or self._actionRegistry == nil then
		return Result.Err("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, {
			Reason = "PolicyNotInitialized",
		})
	end

	return self:_ValidateNode(definition, "Root", 1)
end

function AIBehaviorDefinitionPolicy:_ValidateNode(node: any, path: string, depth: number): Result.Result<any>
	local depthResult = self:_EvaluateSpec(AIBehaviorDefinitionSpecs.IsWithinMaxDepth, {
		Depth = depth,
		MaxDepth = self._maxDepth,
	}, path, "DefinitionTooDeep")
	if not depthResult.success then
		return depthResult
	end

	local nodeShapeResult = self:_EvaluateSpec(AIBehaviorDefinitionSpecs.HasSupportedNodeType, {
		Node = node,
	}, path, "InvalidNodeType")
	if not nodeShapeResult.success then
		return nodeShapeResult
	end

	if type(node) == "string" then
		return self:_ValidateLeaf(node, path)
	end

	return self:_ValidateComposite(node, path, depth)
end

function AIBehaviorDefinitionPolicy:_ValidateLeaf(leafName: string, path: string): Result.Result<any>
	local nonEmptyResult = self:_EvaluateSpec(AIBehaviorDefinitionSpecs.HasNonEmptyLeaf, {
		LeafName = leafName,
	}, path, "InvalidLeaf")
	if not nonEmptyResult.success then
		return nonEmptyResult
	end

	local isEvaluation = self._evaluationRegistry:GetEvaluation(leafName) ~= nil
	local isAction = self._actionRegistry:GetActionDefinition(leafName) ~= nil
	local candidate = {
		EvaluationRegistered = isEvaluation,
		ActionRegistered = isAction,
		LeafName = leafName,
	}
	local orderedSpecs = {
		{ Spec = AIBehaviorDefinitionSpecs.HasRegisteredLeaf, Reason = "UnknownLeaf" },
		{ Spec = AIBehaviorDefinitionSpecs.HasUnambiguousLeaf, Reason = "AmbiguousLeaf" },
	}

	for _, check in ipairs(orderedSpecs) do
		local leafResult = check.Spec:IsSatisfiedBy(candidate)
		if not leafResult.success then
			return Result.Err(leafResult.type, leafResult.message, {
				Reason = check.Reason,
				Path = path,
				LeafName = leafName,
			})
		end
	end

	return Result.Ok(leafName)
end

function AIBehaviorDefinitionPolicy:_ValidateComposite(node: any, path: string, depth: number): Result.Result<any>
	local compositeResult = self:_ValidateCompositeShape(node, path)
	if not compositeResult.success then
		return compositeResult
	end

	local children = if node.Sequence ~= nil then node.Sequence else node.Priority
	local nodeKind = if node.Sequence ~= nil then "Sequence" else "Priority"
	local orderedSpecs = {
		{ Spec = AIBehaviorDefinitionSpecs.HasChildArray, Reason = ("Missing%sChildren"):format(nodeKind) },
		{ Spec = AIBehaviorDefinitionSpecs.HasChildEntries, Reason = ("Empty%sChildren"):format(nodeKind) },
		{ Spec = AIBehaviorDefinitionSpecs.StartsAtIndexOne, Reason = ("Sparse%sChildren"):format(nodeKind) },
		{ Spec = AIBehaviorDefinitionSpecs.HasDenseArrayKeys, Reason = ("Sparse%sChildren"):format(nodeKind) },
	}

	for _, check in ipairs(orderedSpecs) do
		local childrenResult = self:_EvaluateSpec(check.Spec, {
			Children = children,
		}, path, check.Reason)
		if not childrenResult.success then
			return childrenResult
		end
	end

	for index, child in ipairs(children) do
		local childResult = self:_ValidateNode(child, ("%s.%s[%d]"):format(path, nodeKind, index), depth + 1)
		if not childResult.success then
			return childResult
		end
	end

	return Result.Ok(node)
end

function AIBehaviorDefinitionPolicy:_ValidateCompositeShape(node: any, path: string): Result.Result<any>
	local orderedSpecs = {
		{ Spec = AIBehaviorDefinitionSpecs.HasCompositeKind, Reason = "MissingCompositeKind" },
		{ Spec = AIBehaviorDefinitionSpecs.HasSingleCompositeKind, Reason = "MultipleCompositeKinds" },
		{ Spec = AIBehaviorDefinitionSpecs.HasSupportedCompositeKeys, Reason = "UnsupportedCompositeKey" },
	}

	for _, check in ipairs(orderedSpecs) do
		local result = self:_EvaluateSpec(check.Spec, {
			Node = node,
		}, path, check.Reason)
		if not result.success then
			return result
		end
	end

	return Result.Ok(node)
end

function AIBehaviorDefinitionPolicy:_EvaluateSpec(
	spec: any,
	candidate: { [string]: any },
	path: string,
	reason: string
): Result.Result<any>
	local result = spec:IsSatisfiedBy(candidate)
	if result.success then
		return result
	end

	return Result.Err(result.type, result.message or Errors.INVALID_BEHAVIOR_DEFINITION, {
		Reason = reason,
		Path = path,
	})
end

return AIBehaviorDefinitionPolicy
