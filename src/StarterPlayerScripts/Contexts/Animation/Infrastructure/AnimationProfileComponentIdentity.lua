--!strict

local AnimationProfileComponentIdentity = {}

local DEFAULT_VARIANT_ID = "Default"

local function _NormalizeVariantId(variantId: any): string
	return if type(variantId) == "string" and variantId ~= "" then variantId else DEFAULT_VARIANT_ID
end

local function _CloneValue(value: any, clonedBySource: { [table]: table }): any
	if type(value) ~= "table" then
		return value
	end

	local existing = clonedBySource[value]
	if existing ~= nil then
		return existing
	end

	local clone = {}
	clonedBySource[value] = clone
	for key, nestedValue in pairs(value) do
		clone[_CloneValue(key, clonedBySource)] = _CloneValue(nestedValue, clonedBySource)
	end
	return clone
end

local function _AreValuesEqual(left: any, right: any, comparedRightByLeft: { [table]: { [table]: boolean } }): boolean
	local valueType = typeof(left)
	if valueType ~= typeof(right) then
		return false
	end

	if valueType ~= "table" then
		if valueType == "nil" or valueType == "boolean" or valueType == "number" or valueType == "string" then
			return left == right
		end
		return false
	end

	local comparedRights = comparedRightByLeft[left]
	if comparedRights ~= nil and comparedRights[right] == true then
		return true
	end
	if comparedRights == nil then
		comparedRights = {}
		comparedRightByLeft[left] = comparedRights
	end
	comparedRights[right] = true

	for key, leftValue in pairs(left) do
		if not _AreValuesEqual(leftValue, right[key], comparedRightByLeft) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end

	return true
end

function AnimationProfileComponentIdentity.Snapshot(profileComponent: any): any
	return {
		ProfileId = profileComponent.ProfileId,
		AnimationSetId = profileComponent.AnimationSetId,
		VariantId = _NormalizeVariantId(profileComponent.VariantId),
		FeatureOverrides = _CloneValue(profileComponent.FeatureOverrides, {}),
	}
end

function AnimationProfileComponentIdentity.Matches(snapshot: any, profileComponent: any): boolean
	if type(snapshot) ~= "table" or type(profileComponent) ~= "table" then
		return false
	end

	return snapshot.ProfileId == profileComponent.ProfileId
		and snapshot.AnimationSetId == profileComponent.AnimationSetId
		and snapshot.VariantId == _NormalizeVariantId(profileComponent.VariantId)
		and _AreValuesEqual(snapshot.FeatureOverrides, profileComponent.FeatureOverrides, {})
end

return table.freeze(AnimationProfileComponentIdentity)
