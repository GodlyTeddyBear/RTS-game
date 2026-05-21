--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TActorLabelCandidate = {
	ActorLabel: any,
}

local HasValidActorLabel = Spec.new(
	"InvalidActorLabel",
	"AiAdapterFactory ActorLabel must be a non-empty string",
	function(candidate: TActorLabelCandidate): boolean
		local actorLabel = candidate.ActorLabel
		return actorLabel == nil or (type(actorLabel) == "string" and #actorLabel > 0)
	end
)

return table.freeze({
	HasValidActorLabel = HasValidActorLabel,
})
