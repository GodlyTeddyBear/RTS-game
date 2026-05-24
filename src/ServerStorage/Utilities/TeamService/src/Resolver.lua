--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TMemberKey = Types.TMemberKey
type TMemberRef = Types.TMemberRef
type TResolvedTeamManagerConfig = Types.TResolvedTeamManagerConfig

local TEAM_MEMBER_ID_ATTRIBUTE = "TeamMemberId"
local PLAYER_KEY_PREFIX = "player:"

local Resolver = {}

local function _TryCustomResolver(config: TResolvedTeamManagerConfig, memberRef: TMemberRef): TMemberKey?
	if config.ResolveMemberKey == nil then
		return nil
	end

	local customKey = config.ResolveMemberKey(memberRef)
	if customKey == nil then
		return nil
	end

	assert(type(customKey) == "string" and customKey ~= "", "TeamService ResolveMemberKey must return a non-empty string")
	return customKey
end

local function _ResolveInstanceMemberKey(instance: Instance, config: TResolvedTeamManagerConfig): TMemberKey
	local attributeValue = instance:GetAttribute(TEAM_MEMBER_ID_ATTRIBUTE)
	if type(attributeValue) == "string" and attributeValue ~= "" then
		return attributeValue
	end

	local customKey = _TryCustomResolver(config, instance)
	assert(
		customKey ~= nil,
		(`TeamService could not resolve a member key for instance "%s"; set TeamMemberId or provide ResolveMemberKey`):format(
			instance:GetFullName()
		)
	)
	return customKey
end

function Resolver.ResolveMemberKey(config: TResolvedTeamManagerConfig, memberRef: TMemberRef): TMemberKey
	local memberType = typeof(memberRef)

	if memberType == "Instance" then
		local instance = memberRef :: Instance
		if instance:IsA("Player") then
			return PLAYER_KEY_PREFIX .. tostring((instance :: Player).UserId)
		end

		return _ResolveInstanceMemberKey(instance, config)
	end

	if type(memberRef) == "string" then
		Validation.ValidateMemberKey(memberRef)
		return memberRef
	end

	if type(memberRef) == "table" then
		local memberDescriptor = memberRef :: Types.TMemberDescriptor
		assert(type(memberDescriptor.Kind) == "string" and memberDescriptor.Kind ~= "", "TeamService expected member Kind")
		assert(type(memberDescriptor.Id) == "string" and memberDescriptor.Id ~= "", "TeamService expected member Id")
		assert(
			memberDescriptor.Instance == nil or typeof(memberDescriptor.Instance) == "Instance",
			"TeamService expected member Instance to be an Instance when provided"
		)

		return memberDescriptor.Kind .. ":" .. memberDescriptor.Id
	end

	local customKey = _TryCustomResolver(config, memberRef)
	assert(customKey ~= nil, "TeamService could not resolve a member key for the provided member reference")
	return customKey
end

function Resolver.ResolveMemberLabel(config: TResolvedTeamManagerConfig, memberRef: TMemberRef): string?
	if config.ResolveMemberLabel ~= nil then
		local label = config.ResolveMemberLabel(memberRef)
		assert(label == nil or type(label) == "string", "TeamService ResolveMemberLabel must return a string or nil")
		return label
	end

	if typeof(memberRef) == "Instance" then
		return (memberRef :: Instance).Name
	end

	if type(memberRef) == "table" then
		local memberDescriptor = memberRef :: Types.TMemberDescriptor
		return memberDescriptor.Kind .. ":" .. memberDescriptor.Id
	end

	if type(memberRef) == "string" then
		return memberRef
	end

	return nil
end

function Resolver.IsPlayer(memberRef: TMemberRef): boolean
	return typeof(memberRef) == "Instance" and (memberRef :: Instance):IsA("Player")
end

return table.freeze(Resolver)
