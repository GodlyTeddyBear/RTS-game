--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local CompleteEntityRegistrationCommand = {}
CompleteEntityRegistrationCommand.__index = CompleteEntityRegistrationCommand
setmetatable(CompleteEntityRegistrationCommand, BaseCommand)

function CompleteEntityRegistrationCommand.new()
	local self = BaseCommand.new("Entity", "CompleteEntityRegistration")
	return setmetatable(self, CompleteEntityRegistrationCommand)
end

function CompleteEntityRegistrationCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_registrationBarrier = "EntityRegistrationBarrierService",
		_startupState = "EntityStartupStateService",
	})
end

function CompleteEntityRegistrationCommand:Execute(participantName: string, registrationResult: any): Result.Result<boolean>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(
			self._validationService,
			"CompleteEntityRegistration",
			self._lifecycle:GetState(),
			{ "RegisteringECS" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local completionResult = self._registrationBarrier:Complete(participantName, registrationResult)
		if not completionResult.success then
			return completionResult
		end
		if not registrationResult.success then
			self._startupState:SetLastStartupFailure(registrationResult)
			return registrationResult
		end
		return completionResult
	end, self:_Label())
end

return CompleteEntityRegistrationCommand
