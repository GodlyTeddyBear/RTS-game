--!strict

local CollectionService = game:GetService("CollectionService")

local Types = require(script.Parent.Types)

type TResolvedSearchOptions = Types.TResolvedSearchOptions

local Matchers = {}

function Matchers.MatchesName(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local expectedName = resolvedOptions.Name
	if expectedName == nil then
		return true
	end

	if resolvedOptions.CaseInsensitiveName then
		return string.lower(instance.Name) == string.lower(expectedName)
	end

	return instance.Name == expectedName
end

function Matchers.MatchesNames(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local expectedNames = resolvedOptions.Names
	if expectedNames == nil then
		return true
	end

	local instanceName = instance.Name
	for _, expectedName in expectedNames do
		if resolvedOptions.CaseInsensitiveName then
			if string.lower(instanceName) == string.lower(expectedName) then
				return true
			end
		elseif instanceName == expectedName then
			return true
		end
	end

	return false
end

function Matchers.MatchesClass(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	if resolvedOptions.ClassName ~= nil and instance.ClassName ~= resolvedOptions.ClassName then
		return false
	end

	if resolvedOptions.IsA ~= nil and not instance:IsA(resolvedOptions.IsA) then
		return false
	end

	return true
end

function Matchers.MatchesClassNames(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local classNames = resolvedOptions.ClassNames
	if classNames == nil then
		return true
	end

	for _, className in classNames do
		if instance.ClassName == className then
			return true
		end
	end

	return false
end

function Matchers.MatchesIsAAny(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local classNames = resolvedOptions.IsAAny
	if classNames == nil then
		return true
	end

	for _, className in classNames do
		if instance:IsA(className) then
			return true
		end
	end

	return false
end

function Matchers.MatchesAttributes(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local attributes = resolvedOptions.Attributes
	if attributes == nil then
		return true
	end

	for attributeName, expectedValue in attributes do
		if instance:GetAttribute(attributeName) ~= expectedValue then
			return false
		end
	end

	return true
end

function Matchers.MatchesExcludedAttributes(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local attributes = resolvedOptions.ExcludeAttributes
	if attributes == nil then
		return true
	end

	local hasAttributes = false
	for attributeName, expectedValue in attributes do
		hasAttributes = true

		if instance:GetAttribute(attributeName) ~= expectedValue then
			return true
		end
	end

	return not hasAttributes
end

function Matchers.MatchesTags(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local tags = resolvedOptions.Tags
	if tags == nil then
		return true
	end

	for _, tagName in tags do
		if not CollectionService:HasTag(instance, tagName) then
			return false
		end
	end

	return true
end

function Matchers.MatchesTagsAny(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local tags = resolvedOptions.TagsAny
	if tags == nil then
		return true
	end

	for _, tagName in tags do
		if CollectionService:HasTag(instance, tagName) then
			return true
		end
	end

	return false
end

function Matchers.MatchesInstances(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local instances = resolvedOptions.Instances
	if instances == nil then
		return true
	end

	for _, allowedInstance in instances do
		if instance == allowedInstance then
			return true
		end
	end

	return false
end

function Matchers.MatchesExcludedInstances(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local instances = resolvedOptions.ExcludeInstances
	if instances == nil then
		return true
	end

	for _, blockedInstance in instances do
		if instance == blockedInstance then
			return false
		end
	end

	return true
end

function Matchers.MatchesAncestorOf(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local target = resolvedOptions.AncestorOf
	if target == nil then
		return true
	end

	return instance:IsAncestorOf(target)
end

function Matchers.MatchesDescendantOf(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local target = resolvedOptions.DescendantOf
	if target == nil then
		return true
	end

	return instance:IsDescendantOf(target)
end

function Matchers.MatchesExcludedTags(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local tags = resolvedOptions.ExcludeTags
	if tags == nil then
		return true
	end

	for _, tagName in tags do
		if CollectionService:HasTag(instance, tagName) then
			return false
		end
	end

	return true
end

function Matchers.MatchesPredicate(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local predicate = resolvedOptions.Predicate
	if predicate == nil then
		return true
	end

	return predicate(instance)
end

function Matchers.MatchesExcludedPredicate(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local predicate = resolvedOptions.ExcludePredicate
	if predicate == nil then
		return true
	end

	return not predicate(instance)
end

function Matchers.Matches(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	if not Matchers.MatchesName(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesNames(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesClass(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesClassNames(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesIsAAny(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesAttributes(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesTags(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesTagsAny(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesInstances(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesAncestorOf(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesDescendantOf(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesPredicate(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesExcludedAttributes(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesExcludedTags(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesExcludedInstances(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesExcludedPredicate(instance, resolvedOptions) then
		return false
	end

	return true
end

return table.freeze(Matchers)
