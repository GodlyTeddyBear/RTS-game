--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local CompileECSKernelCommand = {}
CompileECSKernelCommand.__index = CompileECSKernelCommand
setmetatable(CompileECSKernelCommand, BaseCommand)

function CompileECSKernelCommand.new()
	local self = BaseCommand.new("Entity", "CompileECSKernel")
	return setmetatable(self, CompileECSKernelCommand)
end

function CompileECSKernelCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_schemaRegistry = "EntitySchemaRegistry",
		_systemRegistry = "EntitySystemRegistry",
		_worldRegistry = "EntityWorldRegistryService",
		_lifecyclePolicy = "EntityLifecyclePolicy",
	})
end

function CompileECSKernelCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local currentState = self._lifecycle:GetState()
		if currentState == "RegisteringECS" then
			local transitionResult = self._lifecycle:BeginECSCompile()
			if not transitionResult.success then
				return transitionResult
			end

			local beginCompileResult = self._schemaRegistry:BeginCompile()
			if not beginCompileResult.success then
				return beginCompileResult
			end

			local scopedBeginResult = self._worldRegistry:BeginCompileSecondaryWorlds()
			if not scopedBeginResult.success then
				return scopedBeginResult
			end

			currentState = self._lifecycle:GetState()
		end

		if currentState == "CompilingECS" then
			local compileResult = self._schemaRegistry:ValidateReady()
			if not compileResult.success then
				return compileResult
			end

			local scopedValidateResult = self._worldRegistry:ValidateSecondaryWorldsReady()
			if not scopedValidateResult.success then
				return scopedValidateResult
			end

			local closeSystemResult = self._systemRegistry:CloseRegistration()
			if not closeSystemResult.success then
				return closeSystemResult
			end

			local finalizeResult = self._schemaRegistry:FinalizeCompile()
			if not finalizeResult.success then
				return finalizeResult
			end

			local scopedFinalizeResult = self._worldRegistry:FinalizeCompileSecondaryWorlds()
			if not scopedFinalizeResult.success then
				return scopedFinalizeResult
			end

			local kernelReadyResult = self._lifecyclePolicy:ValidateKernelReady(self._schemaRegistry, self._systemRegistry)
			if kernelReadyResult ~= nil then
				return kernelReadyResult
			end

			return self._lifecycle:MarkReadyForRuntimeRegistration()
		end

		return Result.Ok(true)
	end, self:_Label())
end

return CompileECSKernelCommand
