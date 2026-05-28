--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BehaviorSystem = require(ServerStorage.Utilities.ContextUtilities.AI.Behavior)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local AIBehaviorDefinitionCompiler = {}
AIBehaviorDefinitionCompiler.__index = AIBehaviorDefinitionCompiler

function AIBehaviorDefinitionCompiler.new()
	return setmetatable({}, AIBehaviorDefinitionCompiler)
end

function AIBehaviorDefinitionCompiler:Init(registry: any, _name: string)
	self._evaluationRegistry = registry:Get("AIEvaluationRegistry")
	self._actionRegistry = registry:Get("AIActionDefinitionRegistry")
end

function AIBehaviorDefinitionCompiler:Compile(definition: any): Result.Result<any>
	return Result.Catch(function()
		local registries = self:_BuildBehaviorSystemRegistries(definition)
		local builder = BehaviorSystem.Builder.new({
			Conditions = registries.Conditions,
			Commands = registries.Commands,
		})

		return Result.Ok(builder:Build(definition))
	end, "AIBehaviorDefinitionCompiler:Compile")
end

function AIBehaviorDefinitionCompiler:_BuildBehaviorSystemRegistries(definition: any): any
	local leaves = {}
	self:_CollectLeaves(definition, leaves)

	local conditions = {}
	local commands = {}
	for leafName in pairs(leaves) do
		local evaluation = self._evaluationRegistry:GetEvaluation(leafName)
		local action = self._actionRegistry:GetActionDefinition(leafName)

		if evaluation ~= nil then
			conditions[leafName] = self:_CreateEvaluationBuilder(evaluation)
		end
		if action ~= nil then
			commands[leafName] = self:_CreateActionBuilder(action)
		end
	end

	return {
		Conditions = conditions,
		Commands = commands,
	}
end

function AIBehaviorDefinitionCompiler:_CollectLeaves(node: any, leaves: { [string]: boolean })
	if type(node) == "string" then
		leaves[node] = true
		return
	end
	if type(node) ~= "table" then
		return
	end

	local children = if node.Sequence ~= nil then node.Sequence else node.Priority
	if type(children) ~= "table" then
		return
	end

	for _, child in ipairs(children) do
		self:_CollectLeaves(child, leaves)
	end
end

function AIBehaviorDefinitionCompiler:_CreateEvaluationBuilder(evaluation: any): () -> any
	return function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task: any, context: any)
			local passed = evaluation.Evaluate(context)
			if passed then
				task:success()
				return
			end

			task:fail()
		end)
	end
end

function AIBehaviorDefinitionCompiler:_CreateActionBuilder(action: any): () -> any
	return function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task: any, context: any)
			if type(context) == "table" then
				context.ActionId = action.ActionId
				context.ActionIntent = action.ProduceIntent(context)
			else
				action.ProduceIntent(context)
			end

			task:success()
		end)
	end
end

function AIBehaviorDefinitionCompiler:BuildCompilationFailure(definitionId: string, compileResult: any): Result.Result<any>
	return Result.Err("BehaviorDefinitionCompilationFailed", Errors.BEHAVIOR_DEFINITION_COMPILATION_FAILED, {
		DefinitionId = definitionId,
		CauseType = compileResult.type,
		CauseMessage = compileResult.message,
		Details = compileResult.data,
	})
end

return AIBehaviorDefinitionCompiler
