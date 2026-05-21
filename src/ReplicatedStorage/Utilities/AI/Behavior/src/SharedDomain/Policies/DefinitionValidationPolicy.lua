--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local ScratchRecycler = require(ReplicatedStorage.Utilities.AI.src.Infrastructure.ScratchRecycler)
local ChildArraySpec = require(script.Parent.Parent.Specs.ChildArraySpec)
local DefinitionNodeSpec = require(script.Parent.Parent.Specs.DefinitionNodeSpec)
local DefinitionRegistrySpec = require(script.Parent.Parent.Specs.DefinitionRegistrySpec)
local DefinitionPath = require(script.Parent.Parent.ValueObjects.DefinitionPath)

local Ok = Result.Ok

local DefinitionValidationPolicy = {}

local function _BuildPathError(result: Result.Err, prefix: string, path: string): Result.Err
	return Result.Err(result.type, ("%s at %s %s"):format(prefix, path, result.message))
end

local function _BuildLeafError(result: Result.Err, name: string, path: string): Result.Err
	if result.type == "UnknownLeaf" then
		return Result.Err(result.type, ("BehaviorSystem leaf '%s' at %s is not registered"):format(name, path))
	end

	return Result.Err(result.type, ("BehaviorSystem leaf '%s' at %s is ambiguous across condition and command registries"):format(name, path))
end

function DefinitionValidationPolicy.CheckRegistryTable(registry: any, label: string): Result.Result<any>
	local candidate = ScratchRecycler.AcquireMap()
	candidate.Label = label
	candidate.Registry = registry

	local result = DefinitionRegistrySpec.HasRegistryTable:IsSatisfiedBy(candidate)
	ScratchRecycler.ReleaseMap(candidate)
	if result.success then
		return result
	end

	return Result.Err((result :: Result.Err).type, ("BehaviorSystem %s registry must be a table"):format(label))
end

function DefinitionValidationPolicy.CheckRegistryFunction(name: any, builder: any, label: string): Result.Result<any>
	local candidate = ScratchRecycler.AcquireMap()
	candidate.Label = label
	candidate.Name = name
	candidate.Builder = builder

	local result = DefinitionRegistrySpec.HasRegistryEntryShape:IsSatisfiedBy(candidate)
	ScratchRecycler.ReleaseMap(candidate)
	if result.success then
		return result
	end

	if type(name) ~= "string" or #name == 0 then
		return Result.Err((result :: Result.Err).type, ("BehaviorSystem %s registry keys must be non-empty strings"):format(label))
	end

	return Result.Err((result :: Result.Err).type, ("BehaviorSystem %s registry entry '%s' must be a function"):format(label, name))
end

function DefinitionValidationPolicy.CheckNodeShape(node: any, path: string): Result.Result<any>
	local normalizedPath = DefinitionPath.From(path)
	local candidate = ScratchRecycler.AcquireMap()
	candidate.Node = node

	local result = DefinitionNodeSpec.HasValidNodeShape:IsSatisfiedBy(candidate)
	ScratchRecycler.ReleaseMap(candidate)
	if result.success then
		return result
	end

	return _BuildPathError(result :: Result.Err, "BehaviorSystem definition node", normalizedPath)
end

function DefinitionValidationPolicy.CheckNonEmptyChildren(children: any, path: string, nodeType: string): Result.Result<any>
	local normalizedPath = DefinitionPath.From(path)
	local candidate = ScratchRecycler.AcquireMap()
	candidate.Children = children

	local result = ChildArraySpec.HasDenseNonEmptyChildArray:IsSatisfiedBy(candidate)
	ScratchRecycler.ReleaseMap(candidate)
	if result.success then
		return result
	end

	return _BuildPathError(result :: Result.Err, ("BehaviorSystem %s node"):format(nodeType), normalizedPath)
end

function DefinitionValidationPolicy.CheckKnownLeaf(
	conditions: { [string]: any },
	commands: { [string]: any },
	name: string,
	path: string
): Result.Result<any>
	local normalizedPath = DefinitionPath.From(path)
	local candidate = ScratchRecycler.AcquireMap()
	candidate.Name = name
	candidate.Path = normalizedPath
	candidate.InConditions = type(conditions) == "table" and conditions[name] ~= nil
	candidate.InCommands = type(commands) == "table" and commands[name] ~= nil

	local result = DefinitionRegistrySpec.HasKnownLeaf:IsSatisfiedBy(candidate)
	ScratchRecycler.ReleaseMap(candidate)
	if result.success then
		return result
	end

	return _BuildLeafError(result :: Result.Err, name, normalizedPath)
end

function DefinitionValidationPolicy.CheckCompositeShape(node: any, path: string): Result.Result<any>
	local normalizedPath = DefinitionPath.From(path)
	local candidate = ScratchRecycler.AcquireMap()
	candidate.Node = node

	local result = DefinitionNodeSpec.HasValidCompositeShape:IsSatisfiedBy(candidate)
	ScratchRecycler.ReleaseMap(candidate)
	if result.success then
		return result
	end

	return _BuildPathError(result :: Result.Err, "BehaviorSystem composite node", normalizedPath)
end

function DefinitionValidationPolicy.CheckSequenceNode(node: any, path: string): Result.Result<any>
	local normalizedPath = DefinitionPath.From(path)
	local candidate = ScratchRecycler.AcquireMap()
	candidate.Node = node

	local result = DefinitionNodeSpec.HasSequenceNode:IsSatisfiedBy(candidate)
	ScratchRecycler.ReleaseMap(candidate)
	if result.success then
		return result
	end

	return Result.Err((result :: Result.Err).type, ("BehaviorSystem node at %s is not a valid Sequence node"):format(normalizedPath))
end

function DefinitionValidationPolicy.CheckPriorityNode(node: any, path: string): Result.Result<any>
	local normalizedPath = DefinitionPath.From(path)
	local candidate = ScratchRecycler.AcquireMap()
	candidate.Node = node

	local result = DefinitionNodeSpec.HasPriorityNode:IsSatisfiedBy(candidate)
	ScratchRecycler.ReleaseMap(candidate)
	if result.success then
		return result
	end

	return Result.Err((result :: Result.Err).type, ("BehaviorSystem node at %s is not a valid Priority node"):format(normalizedPath))
end

function DefinitionValidationPolicy.CheckDefinitionDepth(depth: number, maxDepth: number, path: string): Result.Result<any>
	local normalizedPath = DefinitionPath.From(path)
	if depth <= maxDepth then
		return Ok(depth)
	end

	return Result.Err("DefinitionTooDeep", ("BehaviorSystem definition node at %s exceeds max depth (%d)"):format(normalizedPath, maxDepth))
end

return table.freeze(DefinitionValidationPolicy)
