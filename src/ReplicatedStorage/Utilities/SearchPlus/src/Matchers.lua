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

function Matchers.MatchesClass(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	if resolvedOptions.ClassName ~= nil and instance.ClassName ~= resolvedOptions.ClassName then
		return false
	end

	if resolvedOptions.IsA ~= nil and not instance:IsA(resolvedOptions.IsA) then
		return false
	end

	return true
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

function Matchers.MatchesPredicate(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	local predicate = resolvedOptions.Predicate
	if predicate == nil then
		return true
	end

	return predicate(instance)
end

function Matchers.Matches(instance: Instance, resolvedOptions: TResolvedSearchOptions): boolean
	if not Matchers.MatchesName(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesClass(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesAttributes(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesTags(instance, resolvedOptions) then
		return false
	end

	if not Matchers.MatchesPredicate(instance, resolvedOptions) then
		return false
	end

	return true
end

return table.freeze(Matchers)
