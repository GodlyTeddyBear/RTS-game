--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)
local EntityRegistrationConfig = require(script.Parent.Parent.Parent.Config.EntityRegistrationConfig)

local EntityRegistrationBarrierService = {}
EntityRegistrationBarrierService.__index = EntityRegistrationBarrierService

local function cloneFailure(result: any)
	return table.freeze({
		Type = result.type,
		Message = result.message,
		Data = result.data,
	})
end

function EntityRegistrationBarrierService.new()
	local expected = {}
	for _, participantName in ipairs(EntityRegistrationConfig.Participants) do
		expected[participantName] = true
	end

	return setmetatable({
		_expected = expected,
		_completed = {},
		_failed = {},
		_ownerReady = false,
		_finalizationClaimed = false,
	}, EntityRegistrationBarrierService)
end

function EntityRegistrationBarrierService:Init(_registry: any, _name: string)
	return
end

function EntityRegistrationBarrierService:Complete(participantName: string, registrationResult: any): Result.Result<boolean>
	if self._expected[participantName] ~= true then
		return Result.Err("UnknownEntityRegistrationParticipant", Errors.UNKNOWN_REGISTRATION_PARTICIPANT, {
			ParticipantName = participantName,
		})
	end
	if self._completed[participantName] ~= nil or self._failed[participantName] ~= nil then
		return Result.Err("DuplicateEntityRegistrationCompletion", Errors.DUPLICATE_REGISTRATION_COMPLETION, {
			ParticipantName = participantName,
		})
	end
	if type(registrationResult) ~= "table" or type(registrationResult.success) ~= "boolean" then
		return Result.Err("InvalidEntityRegistrationResult", Errors.INVALID_REGISTRATION_RESULT, {
			ParticipantName = participantName,
		})
	end

	if registrationResult.success then
		self._completed[participantName] = true
	else
		self._failed[participantName] = cloneFailure(registrationResult)
	end
	return Result.Ok(self:IsReadyToFinalize())
end

function EntityRegistrationBarrierService:MarkOwnerReady(): Result.Result<boolean>
	self._ownerReady = true
	return Result.Ok(self:IsReadyToFinalize())
end

function EntityRegistrationBarrierService:ClaimFinalization(): boolean
	if not self:IsReadyToFinalize() or self._finalizationClaimed then
		return false
	end
	self._finalizationClaimed = true
	return true
end

function EntityRegistrationBarrierService:IsReadyToFinalize(): boolean
	if not self._ownerReady or next(self._failed) ~= nil then
		return false
	end
	for participantName in pairs(self._expected) do
		if self._completed[participantName] ~= true then
			return false
		end
	end
	return true
end

function EntityRegistrationBarrierService:GetStatus(): any
	local completed = {}
	local failed = {}
	local pending = {}
	for participantName in pairs(self._expected) do
		if self._completed[participantName] == true then
			table.insert(completed, participantName)
		elseif self._failed[participantName] ~= nil then
			failed[participantName] = self._failed[participantName]
		else
			table.insert(pending, participantName)
		end
	end
	table.sort(completed)
	table.sort(pending)
	return table.freeze({
		OwnerReady = self._ownerReady,
		FinalizationClaimed = self._finalizationClaimed,
		ReadyToFinalize = self:IsReadyToFinalize(),
		Completed = table.freeze(completed),
		Failed = table.freeze(failed),
		Pending = table.freeze(pending),
	})
end

return EntityRegistrationBarrierService
