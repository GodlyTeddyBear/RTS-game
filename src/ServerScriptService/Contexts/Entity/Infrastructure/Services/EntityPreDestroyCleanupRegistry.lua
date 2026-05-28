--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TPreDestroyCleanupPayload = {
	ContributorId: string,
	Cleanup: (entity: number) -> any,
}

local EntityPreDestroyCleanupRegistry = {}
EntityPreDestroyCleanupRegistry.__index = EntityPreDestroyCleanupRegistry

function EntityPreDestroyCleanupRegistry.new()
	local self = setmetatable({}, EntityPreDestroyCleanupRegistry)
	self._contributorsById = {}
	self._orderedContributors = {}
	return self
end

function EntityPreDestroyCleanupRegistry:Init(_registry: any, _name: string)
end

function EntityPreDestroyCleanupRegistry:RegisterContributor(payload: TPreDestroyCleanupPayload): Result.Result<boolean>
	return Result.Catch(function()
		local validationResult = self:_ValidatePayload(payload)
		if not validationResult.success then
			return validationResult
		end

		local contributor = table.freeze({
			ContributorId = payload.ContributorId,
			Cleanup = payload.Cleanup,
		})
		self._contributorsById[payload.ContributorId] = contributor
		table.insert(self._orderedContributors, contributor)

		return Result.Ok(true)
	end, "EntityPreDestroyCleanupRegistry:RegisterContributor")
end

function EntityPreDestroyCleanupRegistry:Run(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		for _, contributor in ipairs(self._orderedContributors) do
			local cleanupResult = self:_RunContributor(contributor, entity)
			if not cleanupResult.success then
				return cleanupResult
			end
		end

		return Result.Ok(true)
	end, "EntityPreDestroyCleanupRegistry:Run")
end

function EntityPreDestroyCleanupRegistry:GetStatus(): any
	return table.freeze({
		ContributorCount = #self._orderedContributors,
	})
end

function EntityPreDestroyCleanupRegistry:_ValidatePayload(payload: TPreDestroyCleanupPayload): Result.Result<boolean>
	if type(payload) ~= "table" or type(payload.ContributorId) ~= "string" or payload.ContributorId == "" then
		return Result.Err("InvalidPreDestroyCleanup", Errors.INVALID_PRE_DESTROY_CLEANUP, {
			Reason = "MissingContributorId",
		})
	end
	if type(payload.Cleanup) ~= "function" then
		return Result.Err("InvalidPreDestroyCleanup", Errors.INVALID_PRE_DESTROY_CLEANUP, {
			ContributorId = payload.ContributorId,
			Reason = "MissingCleanupCallback",
		})
	end
	if self._contributorsById[payload.ContributorId] ~= nil then
		return Result.Err("DuplicatePreDestroyCleanup", Errors.DUPLICATE_PRE_DESTROY_CLEANUP, {
			ContributorId = payload.ContributorId,
		})
	end

	return Result.Ok(true)
end

function EntityPreDestroyCleanupRegistry:_RunContributor(contributor: any, entity: number): Result.Result<boolean>
	local didRun, cleanupResult = pcall(contributor.Cleanup, entity)
	if not didRun then
		return Result.Err("PreDestroyCleanupFailed", Errors.PRE_DESTROY_CLEANUP_FAILED, {
			ContributorId = contributor.ContributorId,
			Entity = entity,
			Reason = tostring(cleanupResult),
		})
	end

	if Result.isResult(cleanupResult) then
		if cleanupResult.success then
			return Result.Ok(true)
		end

		return Result.Err("PreDestroyCleanupFailed", Errors.PRE_DESTROY_CLEANUP_FAILED, {
			ContributorId = contributor.ContributorId,
			Entity = entity,
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
			Details = cleanupResult.data,
		})
	end

	if cleanupResult == false then
		return Result.Err("PreDestroyCleanupFailed", Errors.PRE_DESTROY_CLEANUP_FAILED, {
			ContributorId = contributor.ContributorId,
			Entity = entity,
			Reason = "CleanupReturnedFalse",
		})
	end

	return Result.Ok(true)
end

return EntityPreDestroyCleanupRegistry
