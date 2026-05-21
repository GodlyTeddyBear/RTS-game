--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TCallbackCandidate = {
	ConfigLabel: string,
	CallbackName: string,
	CallbackValue: any,
}

local HasFunctionCallback = Spec.new(
	"MissingRequiredCallback",
	"AiAdapterFactory required callback must be a function",
	function(candidate: TCallbackCandidate): boolean
		return type(candidate.CallbackValue) == "function"
	end
)

return table.freeze({
	HasFunctionCallback = HasFunctionCallback,
})
