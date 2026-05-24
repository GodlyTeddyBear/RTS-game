--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TMemberSnapshot = Types.TMemberSnapshot
type TRelationship = Types.TRelationship
type TStateImportSummary = Types.TStateImportSummary
type TTeamId = Types.TTeamId
type TTeamServiceSnapshot = Types.TTeamServiceSnapshot
type TResolvedTeamDefinition = Types.TResolvedTeamDefinition
type TStoredMemberRecord = Types.TStoredMemberRecord

local StateCodec = {}

function StateCodec.Export(
	teamsById: { [TTeamId]: TResolvedTeamDefinition },
	relationships: { [TTeamId]: { [TTeamId]: TRelationship } },
	membersByKey: { [string]: TStoredMemberRecord }
): TTeamServiceSnapshot
	local teamList = {}
	for _, definition in pairs(teamsById) do
		teamList[#teamList + 1] = Validation.CloneFrozen(definition)
	end

	table.sort(teamList, function(leftDefinition: TResolvedTeamDefinition, rightDefinition: TResolvedTeamDefinition): boolean
		return leftDefinition.TeamId < rightDefinition.TeamId
	end)

	local memberSnapshots = {}
	for memberKey, memberRecord in pairs(membersByKey) do
		local groupIds = Validation.GroupSetToSortedArray(memberRecord.GroupIds)
		memberSnapshots[#memberSnapshots + 1] = {
			MemberKey = memberKey,
			PrimaryTeamId = memberRecord.PrimaryTeamId,
			GroupIds = groupIds,
			MemberRef = memberRecord.Ref,
		}
	end

	table.sort(memberSnapshots, function(leftSnapshot: TMemberSnapshot, rightSnapshot: TMemberSnapshot): boolean
		return leftSnapshot.MemberKey < rightSnapshot.MemberKey
	end)

	local exportedRelationships = Validation.CloneFrozen(relationships)

	return Validation.CloneFrozen({
		Teams = teamList,
		Relationships = exportedRelationships,
		Members = memberSnapshots,
	})
end

function StateCodec.Decode(snapshot: TTeamServiceSnapshot): (
	{ [TTeamId]: TResolvedTeamDefinition },
	{ [TTeamId]: { [TTeamId]: TRelationship } },
	{ [string]: TStoredMemberRecord },
	TStateImportSummary
)
	assert(type(snapshot) == "table", "TeamService expected import snapshot to be a table")
	assert(type(snapshot.Teams) == "table", "TeamService expected snapshot Teams to be an array")
	assert(type(snapshot.Relationships) == "table", "TeamService expected snapshot Relationships to be a table")
	assert(type(snapshot.Members) == "table", "TeamService expected snapshot Members to be an array")

	local teamsById = {}
	for _, definition in ipairs(snapshot.Teams) do
		local normalizedDefinition = Validation.NormalizeTeamDefinition(definition)
		assert(teamsById[normalizedDefinition.TeamId] == nil, "TeamService snapshot contains duplicate team ids")
		teamsById[normalizedDefinition.TeamId] = normalizedDefinition
	end

	local decodedRelationships = {}
	for teamId, relatedEntries in pairs(snapshot.Relationships) do
		Validation.ValidateTeamId(teamId)
		assert(teamsById[teamId] ~= nil, "TeamService snapshot relationship references an unknown team")
		assert(type(relatedEntries) == "table", "TeamService expected relationship entries to be a table")

		decodedRelationships[teamId] = {}
		for relatedTeamId, relationship in pairs(relatedEntries) do
			Validation.ValidateTeamId(relatedTeamId)
			assert(teamsById[relatedTeamId] ~= nil, "TeamService snapshot relationship references an unknown related team")
			Validation.ValidateRelationship(relationship)
			decodedRelationships[teamId][relatedTeamId] = relationship
		end
	end

	local membersByKey = {}
	local groupCount = 0
	for _, memberSnapshot in ipairs(snapshot.Members) do
		assert(type(memberSnapshot) == "table", "TeamService expected member snapshot entries to be tables")
		Validation.ValidateMemberKey(memberSnapshot.MemberKey)
		assert(type(memberSnapshot.GroupIds) == "table", "TeamService expected member snapshot GroupIds to be an array")
		assert(memberSnapshot.MemberRef == nil or Validation.IsSupportedMemberRef(memberSnapshot.MemberRef), "TeamService expected valid MemberRef values in snapshot")
		assert(membersByKey[memberSnapshot.MemberKey] == nil, "TeamService snapshot contains duplicate member keys")

		if memberSnapshot.PrimaryTeamId ~= nil then
			Validation.ValidateTeamId(memberSnapshot.PrimaryTeamId)
			assert(teamsById[memberSnapshot.PrimaryTeamId] ~= nil, "TeamService snapshot member references an unknown primary team")
		end

		local groupSet = {}
		for _, groupId in ipairs(memberSnapshot.GroupIds) do
			Validation.ValidateGroupId(groupId)
			if groupSet[groupId] == nil then
				groupSet[groupId] = true
				groupCount += 1
			end
		end

		membersByKey[memberSnapshot.MemberKey] = {
			PrimaryTeamId = memberSnapshot.PrimaryTeamId,
			GroupIds = groupSet,
			Ref = memberSnapshot.MemberRef,
		}
	end

	return teamsById, decodedRelationships, membersByKey, table.freeze({
		TeamCount = #snapshot.Teams,
		MemberCount = #snapshot.Members,
		GroupCount = groupCount,
	})
end

return table.freeze(StateCodec)
