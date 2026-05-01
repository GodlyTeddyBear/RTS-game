--!strict

--[=[
	@class AIContractTypes
	Lightweight shared AI type contracts that avoid pulling the full AI facade at runtime.
	@server
	@client
]=]

local ContractTypes = {}

export type TRuntimeBindingMethodStatus = {
	MethodName: string,
	HasMethod: boolean,
	RegisteredPhases: { string },
}

export type TRuntimeBindingStatus = {
	TargetField: string,
	TargetExists: boolean,
	Poll: TRuntimeBindingMethodStatus,
	Sync: TRuntimeBindingMethodStatus,
}

export type TRuntimeBindingOwner = {
	GetSchedulerBindingStatus: (self: TRuntimeBindingOwner, serviceField: string) -> any,
}

export type TRegistrationValidationOptions = {
	RuntimeOwner: TRuntimeBindingOwner?,
}

export type TSemanticRequirements = {
	FactsDependOnPolling: boolean?,
	AttributesDependOnProjection: boolean?,
}

export type TRuntimeBinding = {
	ServiceField: string,
	PollPhase: string?,
	SyncPhase: string?,
}

return table.freeze(ContractTypes)
