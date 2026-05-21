--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TChildArrayCandidate = {
	Children: any,
}

local HasChildArrayTable = Spec.new(
	"InvalidChildArray",
	"must contain a child array",
	function(candidate: TChildArrayCandidate): boolean
		return type(candidate.Children) == "table"
	end
)

local HasChildEntries = Spec.new(
	"InvalidChildArray",
	"must contain at least one child",
	function(candidate: TChildArrayCandidate): boolean
		local children = candidate.Children
		return type(children) == "table" and next(children) ~= nil
	end
)

local StartsAtIndexOne = Spec.new(
	"InvalidChildArray",
	"must start at index 1",
	function(candidate: TChildArrayCandidate): boolean
		local children = candidate.Children
		return type(children) == "table" and children[1] ~= nil
	end
)

local HasDenseArrayKeys = Spec.new(
	"InvalidChildArray",
	"has a sparse child array",
	function(candidate: TChildArrayCandidate): boolean
		local children = candidate.Children
		if type(children) ~= "table" then
			return false
		end

		local childCount = 0
		local maxIndex = 0
		for key in pairs(children) do
			if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
				return false
			end

			local numericKey = key :: number
			childCount += 1
			if numericKey > maxIndex then
				maxIndex = numericKey
			end
		end

		return maxIndex == childCount
	end
)

return table.freeze({
	HasDenseNonEmptyChildArray = HasChildArrayTable
		:And(HasChildEntries)
		:And(StartsAtIndexOne)
		:And(HasDenseArrayKeys),
})
