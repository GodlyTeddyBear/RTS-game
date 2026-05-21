--!strict

--[=[
    @class RuntimeBindingSpecs
    Shared specifications that validate actor runtime binding status snapshots.
    @server
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Errors)

--[=[
    @type TRuntimeBindingCandidate
    @within RuntimeBindingSpecs
]=]
export type TRuntimeBindingCandidate = {
	RuntimeBinding: any,
	BindingStatus: any,
}

local RuntimeBindingSpecs = {}

--[=[
    @prop HasRuntimeTarget Specification
    @within RuntimeBindingSpecs
    @readonly
    Checks that the runtime owner exposes the bound target service field.
]=]
RuntimeBindingSpecs.HasRuntimeTarget = Spec.new(
	"InvalidActorRuntimeBindingOwner",
	Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER,
	function(candidate: TRuntimeBindingCandidate): boolean
		local bindingStatus = candidate.BindingStatus
		return type(bindingStatus) == "table" and bindingStatus.TargetExists == true
	end
)

--[=[
    @prop HasPollMethod Specification
    @within RuntimeBindingSpecs
    @readonly
    Checks that the runtime owner exposes the poll method required by the actor type.
]=]
RuntimeBindingSpecs.HasPollMethod = Spec.new(
	"ActorPollingRequirementUnsatisfied",
	Errors.ACTOR_POLL_REQUIREMENT_UNSATISFIED,
	function(candidate: TRuntimeBindingCandidate): boolean
		local bindingStatus = candidate.BindingStatus
		local pollStatus = if type(bindingStatus) == "table" then bindingStatus.Poll else nil
		return type(pollStatus) == "table" and pollStatus.HasMethod == true
	end
)

--[=[
    @prop HasPollPhase Specification
    @within RuntimeBindingSpecs
    @readonly
    Checks that the runtime owner registered the poll phase required by the actor type.
]=]
RuntimeBindingSpecs.HasPollPhase = Spec.new(
	"ActorPollingRequirementUnsatisfied",
	Errors.ACTOR_POLL_REQUIREMENT_UNSATISFIED,
	function(candidate: TRuntimeBindingCandidate): boolean
		local bindingStatus = candidate.BindingStatus
		local pollStatus = if type(bindingStatus) == "table" then bindingStatus.Poll else nil
		if type(pollStatus) ~= "table" or type(pollStatus.RegisteredPhases) ~= "table" then
			return false
		end

		return AI.ContainsPhase(pollStatus.RegisteredPhases, candidate.RuntimeBinding.PollPhase)
	end
)

--[=[
    @prop HasSyncMethod Specification
    @within RuntimeBindingSpecs
    @readonly
    Checks that the runtime owner exposes the sync method required by the actor type.
]=]
RuntimeBindingSpecs.HasSyncMethod = Spec.new(
	"ActorProjectionRequirementUnsatisfied",
	Errors.ACTOR_PROJECTION_REQUIREMENT_UNSATISFIED,
	function(candidate: TRuntimeBindingCandidate): boolean
		local bindingStatus = candidate.BindingStatus
		local syncStatus = if type(bindingStatus) == "table" then bindingStatus.Sync else nil
		return type(syncStatus) == "table" and syncStatus.HasMethod == true
	end
)

--[=[
    @prop HasSyncPhase Specification
    @within RuntimeBindingSpecs
    @readonly
    Checks that the runtime owner registered the sync phase required by the actor type.
]=]
RuntimeBindingSpecs.HasSyncPhase = Spec.new(
	"ActorProjectionRequirementUnsatisfied",
	Errors.ACTOR_PROJECTION_REQUIREMENT_UNSATISFIED,
	function(candidate: TRuntimeBindingCandidate): boolean
		local bindingStatus = candidate.BindingStatus
		local syncStatus = if type(bindingStatus) == "table" then bindingStatus.Sync else nil
		if type(syncStatus) ~= "table" or type(syncStatus.RegisteredPhases) ~= "table" then
			return false
		end

		return AI.ContainsPhase(syncStatus.RegisteredPhases, candidate.RuntimeBinding.SyncPhase)
	end
)

return table.freeze(RuntimeBindingSpecs)
