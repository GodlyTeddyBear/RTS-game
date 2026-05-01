--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TRegistryCandidate = {
	Label: string,
	Registry: any,
}

export type TRegistryEntryCandidate = {
	Label: string,
	Name: any,
	Builder: any,
}

export type TLeafCandidate = {
	Name: string,
	Path: string,
	InConditions: boolean,
	InCommands: boolean,
}

local HasRegistryTable = Spec.new(
	"InvalidRegistry",
	"BehaviorSystem registry must be a table",
	function(candidate: TRegistryCandidate): boolean
		return type(candidate.Registry) == "table"
	end
)

local HasRegistryEntryName = Spec.new(
	"InvalidRegistryEntry",
	"BehaviorSystem registry keys must be non-empty strings",
	function(candidate: TRegistryEntryCandidate): boolean
		return type(candidate.Name) == "string" and #candidate.Name > 0
	end
)

local HasRegistryBuilderFunction = Spec.new(
	"InvalidRegistryEntry",
	"BehaviorSystem registry entry must be a function",
	function(candidate: TRegistryEntryCandidate): boolean
		return type(candidate.Builder) == "function"
	end
)

local HasRegisteredLeaf = Spec.new(
	"UnknownLeaf",
	"BehaviorSystem leaf is not registered",
	function(candidate: TLeafCandidate): boolean
		return candidate.InConditions or candidate.InCommands
	end
)

local HasUnambiguousLeaf = Spec.new(
	"AmbiguousLeaf",
	"BehaviorSystem leaf is ambiguous across condition and command registries",
	function(candidate: TLeafCandidate): boolean
		return not (candidate.InConditions and candidate.InCommands)
	end
)

return table.freeze({
	HasRegistryTable = HasRegistryTable,
	HasRegistryEntryShape = HasRegistryEntryName:And(HasRegistryBuilderFunction),
	HasKnownLeaf = HasRegisteredLeaf:And(HasUnambiguousLeaf),
})
