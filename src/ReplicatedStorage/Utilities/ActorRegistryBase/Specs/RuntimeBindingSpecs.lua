--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Errors)

export type TRuntimeBindingCandidate = {
	RuntimeBinding: any,
	BindingStatus: any,
}

local HasRuntimeTarget = Spec.new(
	"InvalidActorRuntimeBindingOwner",
	Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER,
	function(candidate: TRuntimeBindingCandidate): boolean
		local bindingStatus = candidate.BindingStatus
		return type(bindingStatus) == "table" and bindingStatus.TargetExists == true
	end
)

local HasPollMethod = Spec.new(
	"ActorPollingRequirementUnsatisfied",
	Errors.ACTOR_POLL_REQUIREMENT_UNSATISFIED,
	function(candidate: TRuntimeBindingCandidate): boolean
		local bindingStatus = candidate.BindingStatus
		local pollStatus = if type(bindingStatus) == "table" then bindingStatus.Poll else nil
		return type(pollStatus) == "table" and pollStatus.HasMethod == true
	end
)

local HasPollPhase = Spec.new(
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

local HasSyncMethod = Spec.new(
	"ActorProjectionRequirementUnsatisfied",
	Errors.ACTOR_PROJECTION_REQUIREMENT_UNSATISFIED,
	function(candidate: TRuntimeBindingCandidate): boolean
		local bindingStatus = candidate.BindingStatus
		local syncStatus = if type(bindingStatus) == "table" then bindingStatus.Sync else nil
		return type(syncStatus) == "table" and syncStatus.HasMethod == true
	end
)

local HasSyncPhase = Spec.new(
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

return table.freeze({
	HasRuntimeTarget = HasRuntimeTarget,
	HasPollMethod = HasPollMethod,
	HasPollPhase = HasPollPhase,
	HasSyncMethod = HasSyncMethod,
	HasSyncPhase = HasSyncPhase,
})
