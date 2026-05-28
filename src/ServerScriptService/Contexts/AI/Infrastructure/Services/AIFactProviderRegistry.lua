--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TAIFactProviderPayload = AISharedContract.TAIFactProviderPayload
type TAIFactProviderContext = AISharedContract.TAIFactProviderContext

local AIFactProviderRegistry = {}
AIFactProviderRegistry.__index = AIFactProviderRegistry

function AIFactProviderRegistry.new()
	local self = setmetatable({}, AIFactProviderRegistry)
	self._providersById = {}
	self._orderedProviders = {}
	return self
end

function AIFactProviderRegistry:Init(_registry: any, _name: string)
end

function AIFactProviderRegistry:RegisterFactProvider(payload: TAIFactProviderPayload): Result.Result<boolean>
	return Result.Catch(function()
		local validationResult = self:_ValidatePayload(payload)
		if not validationResult.success then
			return validationResult
		end

		local providerRecord = table.freeze({
			ProviderId = payload.ProviderId,
			BuildFacts = payload.BuildFacts,
			Metadata = self:_CloneAndFreeze(payload.Metadata),
		})
		self._providersById[payload.ProviderId] = providerRecord
		table.insert(self._orderedProviders, providerRecord)
		return Result.Ok(true)
	end, "AIFactProviderRegistry:RegisterFactProvider")
end

function AIFactProviderRegistry:GetProvider(providerId: string): any?
	return self._providersById[providerId]
end

function AIFactProviderRegistry:BuildFacts(context: TAIFactProviderContext): Result.Result<any>
	return Result.Catch(function()
		local facts = {}
		for _, provider in ipairs(self._orderedProviders) do
			local providerFactsResult = self:_RunProvider(provider, context)
			if not providerFactsResult.success then
				return providerFactsResult
			end

			local mergeResult = self:_MergeFacts(facts, providerFactsResult.value, provider.ProviderId)
			if not mergeResult.success then
				return mergeResult
			end
		end

		return Result.Ok(facts)
	end, "AIFactProviderRegistry:BuildFacts")
end

function AIFactProviderRegistry:GetStatus(): any
	return table.freeze({
		FactProviderCount = #self._orderedProviders,
	})
end

function AIFactProviderRegistry:_ValidatePayload(payload: TAIFactProviderPayload): Result.Result<boolean>
	if type(payload) ~= "table" or type(payload.ProviderId) ~= "string" or payload.ProviderId == "" then
		return Result.Err("InvalidFactProvider", Errors.INVALID_FACT_PROVIDER, {
			Reason = "MissingProviderId",
		})
	end
	if type(payload.BuildFacts) ~= "function" then
		return Result.Err("InvalidFactProvider", Errors.INVALID_FACT_PROVIDER, {
			ProviderId = payload.ProviderId,
			Reason = "MissingBuildFactsCallback",
		})
	end
	if self._providersById[payload.ProviderId] ~= nil then
		return Result.Err("DuplicateFactProvider", Errors.DUPLICATE_FACT_PROVIDER, {
			ProviderId = payload.ProviderId,
		})
	end

	return Result.Ok(true)
end

function AIFactProviderRegistry:_RunProvider(provider: any, context: any): Result.Result<any>
	local didBuild, buildResult = pcall(provider.BuildFacts, context)
	if not didBuild then
		return Result.Err("AIFactBuildFailed", Errors.AI_FACT_BUILD_FAILED, {
			ProviderId = provider.ProviderId,
			Reason = tostring(buildResult),
		})
	end

	if Result.isResult(buildResult) then
		if not buildResult.success then
			return Result.Err("AIFactBuildFailed", Errors.AI_FACT_BUILD_FAILED, {
				ProviderId = provider.ProviderId,
				CauseType = buildResult.type,
				CauseMessage = buildResult.message,
				Details = buildResult.data,
			})
		end
		buildResult = buildResult.value
	end

	if type(buildResult) ~= "table" then
		return Result.Err("AIFactBuildFailed", Errors.AI_FACT_BUILD_FAILED, {
			ProviderId = provider.ProviderId,
			Reason = "FactsMustBeTable",
		})
	end

	return Result.Ok(buildResult)
end

function AIFactProviderRegistry:_MergeFacts(target: any, source: any, providerId: string): Result.Result<boolean>
	for key, value in pairs(source) do
		if target[key] ~= nil then
			return Result.Err("DuplicateFactKey", Errors.DUPLICATE_FACT_KEY, {
				ProviderId = providerId,
				FactKey = key,
			})
		end
		target[key] = value
	end

	return Result.Ok(true)
end

function AIFactProviderRegistry:_CloneAndFreeze(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = self:_CloneAndFreeze(nestedValue)
	end

	return table.freeze(clone)
end

return AIFactProviderRegistry
