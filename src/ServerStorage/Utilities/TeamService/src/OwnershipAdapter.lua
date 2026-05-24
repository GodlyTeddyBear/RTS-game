--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TResolvedOwnershipAdapterInput = Types.TResolvedOwnershipAdapterInput
type TResolvedOwnershipMembership = Types.TResolvedOwnershipMembership

local OwnershipAdapter = {}

function OwnershipAdapter.Resolve(input: TResolvedOwnershipAdapterInput): TResolvedOwnershipMembership
	assert(type(input) == "table", "TeamService expected ownership adapter input to be a table")
	assert(input.Faction == nil or type(input.Faction) == "string", "TeamService expected Faction to be a string when provided")
	assert(
		input.OwnerKind == nil or type(input.OwnerKind) == "string",
		"TeamService expected OwnerKind to be a string when provided"
	)
	assert(input.OwnerId == nil or type(input.OwnerId) == "string", "TeamService expected OwnerId to be a string when provided")

	local groupIds = {}
	if input.OwnerKind ~= nil or input.OwnerId ~= nil then
		assert(input.OwnerKind ~= nil and input.OwnerKind ~= "", "TeamService expected OwnerKind when OwnerId mapping is requested")
		assert(input.OwnerId ~= nil and input.OwnerId ~= "", "TeamService expected OwnerId when ownership mapping is requested")
		groupIds[1] = Validation.BuildOwnerGroupId(input.OwnerKind, input.OwnerId)
	end

	return Validation.CloneFrozen({
		PrimaryTeamId = if input.Faction ~= nil and input.Faction ~= "" then input.Faction else nil,
		GroupIds = groupIds,
	})
end

return table.freeze(OwnershipAdapter)
