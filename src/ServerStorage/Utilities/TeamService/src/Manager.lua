--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)

local OwnershipAdapter = require(script.Parent.OwnershipAdapter)
local Relationships = require(script.Parent.Relationships)
local Resolver = require(script.Parent.Resolver)
local RobloxTeamsAdapter = require(script.Parent.RobloxTeamsAdapter)
local StateCodec = require(script.Parent.StateCodec)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TGroupId = Types.TGroupId
type TMemberKey = Types.TMemberKey
type TMemberRef = Types.TMemberRef
type TRegisteredMember = Types.TRegisteredMember
type TRelationship = Types.TRelationship
type TResolvedOwnershipAdapterInput = Types.TResolvedOwnershipAdapterInput
type TResolvedOwnershipMembership = Types.TResolvedOwnershipMembership
type TResolvedTeamDefinition = Types.TResolvedTeamDefinition
type TResolvedTeamManagerConfig = Types.TResolvedTeamManagerConfig
type TStateImportSummary = Types.TStateImportSummary
type TStoredMemberRecord = Types.TStoredMemberRecord
type TTeamDefinition = Types.TTeamDefinition
type TTeamId = Types.TTeamId
type TTeamImportOptions = Types.TTeamImportOptions
type TTeamManager = Types.TTeamManager
type TTeamManagerConfig = Types.TTeamManagerConfig
type TTeamRemoveOptions = Types.TTeamRemoveOptions
type TTeamServiceSnapshot = Types.TTeamServiceSnapshot
type TTeamUpdatePatch = Types.TTeamUpdatePatch

local Manager = {}
Manager.__index = Manager

function Manager.new(config: TTeamManagerConfig?): TTeamManager
	local self = setmetatable({}, Manager) :: any

	self._config = Validation.NormalizeManagerConfig(config) :: TResolvedTeamManagerConfig
	self._teamsById = {} :: { [TTeamId]: TResolvedTeamDefinition }
	self._membersByKey = {} :: { [TMemberKey]: TStoredMemberRecord }
	self._memberKeysByTeamId = {} :: { [TTeamId]: { [TMemberKey]: true } }
	self._memberKeysByGroupId = {} :: { [TGroupId]: { [TMemberKey]: true } }
	self._relationships = {} :: { [TTeamId]: { [TTeamId]: TRelationship } }
	self._connections = {}
	self._isDestroyed = false

	self.TeamCreated = GoodSignal.new()
	self.TeamRemoved = GoodSignal.new()
	self.TeamUpdated = GoodSignal.new()
	self.RelationshipChanged = GoodSignal.new()
	self.MemberAssigned = GoodSignal.new()
	self.MemberUnassigned = GoodSignal.new()
	self.MemberSwitched = GoodSignal.new()
	self.GroupAssigned = GoodSignal.new()
	self.GroupRemoved = GoodSignal.new()
	self.GroupSetChanged = GoodSignal.new()
	self.StateImported = GoodSignal.new()

	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player: Player)
		self:_HandlePlayerRemoving(player)
	end))

	return self :: TTeamManager
end

function Manager:RegisterTeam(definition: TTeamDefinition): TResolvedTeamDefinition
	self:_AssertAlive()

	local normalizedDefinition = Validation.NormalizeTeamDefinition(definition)
	local teamId = normalizedDefinition.TeamId
	assert(self._teamsById[teamId] == nil, (`TeamService team "%s" is already registered`):format(teamId))

	self._teamsById[teamId] = normalizedDefinition
	self._memberKeysByTeamId[teamId] = self._memberKeysByTeamId[teamId] or {}
	self.TeamCreated:Fire(teamId, Validation.CloneFrozen(normalizedDefinition))

	return Validation.CloneFrozen(normalizedDefinition)
end

function Manager:RegisterTeams(definitions: { TTeamDefinition }): { TResolvedTeamDefinition }
	self:_AssertAlive()
	assert(type(definitions) == "table", "TeamService expected definitions to be a table")

	local registeredDefinitions = {}
	for _, definition in ipairs(definitions) do
		registeredDefinitions[#registeredDefinitions + 1] = self:RegisterTeam(definition)
	end

	return registeredDefinitions
end

function Manager:RemoveTeam(teamId: TTeamId, options: TTeamRemoveOptions?): TResolvedTeamDefinition
	self:_AssertAlive()
	Validation.ValidateTeamId(teamId)
	Validation.ValidateRemoveOptions(options)

	local definition = self:_RequireTeam(teamId)
	local memberKeys = self._memberKeysByTeamId[teamId]
	local forceRemove = options ~= nil and options.Force == true

	if memberKeys ~= nil and next(memberKeys) ~= nil then
		assert(forceRemove, (`TeamService cannot remove team "%s" while members are still assigned`):format(teamId))
		self:_ForceUnassignTeamMembers(teamId)
	end

	self._teamsById[teamId] = nil
	self._memberKeysByTeamId[teamId] = nil
	self._relationships[teamId] = nil
	for _, relatedEntries in pairs(self._relationships) do
		relatedEntries[teamId] = nil
	end

	RobloxTeamsAdapter.RemoveTeam(definition)

	local clonedDefinition = Validation.CloneFrozen(definition)
	self.TeamRemoved:Fire(teamId, clonedDefinition)

	return clonedDefinition
end

function Manager:UpdateTeam(teamId: TTeamId, patch: TTeamUpdatePatch): TResolvedTeamDefinition
	self:_AssertAlive()
	Validation.ValidateTeamId(teamId)

	local previousDefinition = self:_RequireTeam(teamId)
	local nextDefinition = Validation.ApplyTeamPatch(previousDefinition, patch)

	self._teamsById[teamId] = nextDefinition
	self:ClearRobloxProjection(teamId)
	self:_ResyncPlayersForTeam(teamId)
	self.TeamUpdated:Fire(teamId, Validation.CloneFrozen(nextDefinition), Validation.CloneFrozen(previousDefinition))

	return Validation.CloneFrozen(nextDefinition)
end

function Manager:HasTeam(teamId: TTeamId): boolean
	Validation.ValidateTeamId(teamId)
	return self._teamsById[teamId] ~= nil
end

function Manager:GetTeam(teamId: TTeamId): TResolvedTeamDefinition?
	Validation.ValidateTeamId(teamId)

	local definition = self._teamsById[teamId]
	if definition == nil then
		return nil
	end

	return Validation.CloneFrozen(definition)
end

function Manager:ListTeams(): { TResolvedTeamDefinition }
	return Validation.CloneFrozen(StateCodec.Export(self._teamsById, {}, {}).Teams)
end

function Manager:SetRelationship(teamA: TTeamId, teamB: TTeamId, relationship: TRelationship): TRelationship
	self:_AssertAlive()
	Validation.ValidateTeamId(teamA)
	Validation.ValidateTeamId(teamB)
	Validation.ValidateRelationship(relationship)
	self:_RequireTeam(teamA)
	self:_RequireTeam(teamB)

	if teamA == teamB then
		relationship = Relationships.Relationship.Ally
	end

	self._relationships[teamA] = self._relationships[teamA] or {}
	self._relationships[teamB] = self._relationships[teamB] or {}
	self._relationships[teamA][teamB] = relationship
	self._relationships[teamB][teamA] = relationship

	self.RelationshipChanged:Fire(teamA, teamB, relationship)

	return relationship
end

function Manager:GetRelationshipByTeamIds(teamA: TTeamId, teamB: TTeamId): TRelationship?
	Validation.ValidateTeamId(teamA)
	Validation.ValidateTeamId(teamB)

	if self._teamsById[teamA] == nil or self._teamsById[teamB] == nil then
		return nil
	end

	if teamA == teamB then
		return Relationships.Relationship.Ally
	end

	local relatedEntries = self._relationships[teamA]
	if relatedEntries == nil then
		return Relationships.Relationship.Neutral
	end

	return relatedEntries[teamB] or Relationships.Relationship.Neutral
end

function Manager:AssignMember(memberRef: TMemberRef, teamId: TTeamId): TResolvedTeamDefinition
	self:_AssertAlive()
	Validation.ValidateTeamId(teamId)

	local definition = self:_RequireTeam(teamId)
	local memberKey = self:GetMemberKey(memberRef)
	local memberRecord = self:_GetOrCreateMemberRecord(memberKey, memberRef)
	local previousTeamId = memberRecord.PrimaryTeamId

	if previousTeamId == teamId then
		memberRecord.Ref = memberRef
		self:_SyncMemberProjection(memberRef, definition)
		return Validation.CloneFrozen(definition)
	end

	if previousTeamId ~= nil then
		self:_RemoveMemberFromTeamIndex(memberKey, previousTeamId)
	end

	memberRecord.PrimaryTeamId = teamId
	memberRecord.Ref = memberRef
	self._memberKeysByTeamId[teamId] = self._memberKeysByTeamId[teamId] or {}
	self._memberKeysByTeamId[teamId][memberKey] = true

	self:_SyncMemberProjection(memberRef, definition)

	if previousTeamId == nil then
		self.MemberAssigned:Fire(memberKey, teamId, memberRef)
	else
		self.MemberSwitched:Fire(memberKey, previousTeamId, teamId, memberRef)
	end

	return Validation.CloneFrozen(definition)
end

function Manager:AssignMembers(memberRefs: { TMemberRef }, teamId: TTeamId): number
	self:_AssertAlive()
	Validation.ValidateTeamId(teamId)
	self:_RequireTeam(teamId)
	assert(type(memberRefs) == "table", "TeamService expected memberRefs to be an array")

	for _, memberRef in ipairs(memberRefs) do
		self:GetMemberKey(memberRef)
	end

	for _, memberRef in ipairs(memberRefs) do
		self:AssignMember(memberRef, teamId)
	end

	return #memberRefs
end

function Manager:UnassignMember(memberRef: TMemberRef): TTeamId?
	self:_AssertAlive()

	local memberKey = self:GetMemberKey(memberRef)
	local memberRecord = self._membersByKey[memberKey]
	if memberRecord == nil or memberRecord.PrimaryTeamId == nil then
		return nil
	end

	local previousTeamId = memberRecord.PrimaryTeamId
	local storedMemberRef = if memberRecord.Ref ~= nil then memberRecord.Ref else memberRef
	memberRecord.PrimaryTeamId = nil
	memberRecord.Ref = storedMemberRef

	self:_RemoveMemberFromTeamIndex(memberKey, previousTeamId)
	self:_ClearMemberProjection(storedMemberRef)
	self.MemberUnassigned:Fire(memberKey, previousTeamId, storedMemberRef)
	self:_PruneMemberRecordIfEmpty(memberKey)

	return previousTeamId
end

function Manager:UnassignMembers(memberRefs: { TMemberRef }): number
	self:_AssertAlive()
	assert(type(memberRefs) == "table", "TeamService expected memberRefs to be an array")

	for _, memberRef in ipairs(memberRefs) do
		self:GetMemberKey(memberRef)
	end

	local removedCount = 0
	for _, memberRef in ipairs(memberRefs) do
		if self:UnassignMember(memberRef) ~= nil then
			removedCount += 1
		end
	end

	return removedCount
end

function Manager:SwitchMember(memberRef: TMemberRef, nextTeamId: TTeamId): TResolvedTeamDefinition
	return self:AssignMember(memberRef, nextTeamId)
end

function Manager:GetMemberTeam(memberRef: TMemberRef): TResolvedTeamDefinition?
	local memberRecord = self:_GetMemberRecordOrNil(memberRef)
	if memberRecord == nil or memberRecord.PrimaryTeamId == nil then
		return nil
	end

	local definition = self._teamsById[memberRecord.PrimaryTeamId]
	if definition == nil then
		return nil
	end

	return Validation.CloneFrozen(definition)
end

function Manager:GetMemberKey(memberRef: TMemberRef): TMemberKey
	return Resolver.ResolveMemberKey(self._config, memberRef)
end

function Manager:ListMembers(teamId: TTeamId): { TRegisteredMember }
	Validation.ValidateTeamId(teamId)
	self:_RequireTeam(teamId)
	return self:_BuildRegisteredMembers(self._memberKeysByTeamId[teamId])
end

function Manager:AddMemberToGroup(memberRef: TMemberRef, groupId: TGroupId): boolean
	self:_AssertAlive()
	Validation.ValidateGroupId(groupId)

	local memberKey = self:GetMemberKey(memberRef)
	local memberRecord = self:_RequireMemberRecord(memberKey)
	if memberRecord.GroupIds[groupId] == true then
		return false
	end

	memberRecord.GroupIds[groupId] = true
	memberRecord.Ref = memberRef
	self._memberKeysByGroupId[groupId] = self._memberKeysByGroupId[groupId] or {}
	self._memberKeysByGroupId[groupId][memberKey] = true
	self.GroupAssigned:Fire(memberKey, groupId, memberRef)

	return true
end

function Manager:RemoveMemberFromGroup(memberRef: TMemberRef, groupId: TGroupId): boolean
	self:_AssertAlive()
	Validation.ValidateGroupId(groupId)

	local memberKey = self:GetMemberKey(memberRef)
	local memberRecord = self:_RequireMemberRecord(memberKey)
	if memberRecord.GroupIds[groupId] ~= true then
		return false
	end

	memberRecord.GroupIds[groupId] = nil
	memberRecord.Ref = if memberRecord.Ref ~= nil then memberRecord.Ref else memberRef

	local groupMembers = self._memberKeysByGroupId[groupId]
	if groupMembers ~= nil then
		groupMembers[memberKey] = nil
		if next(groupMembers) == nil then
			self._memberKeysByGroupId[groupId] = nil
		end
	end

	self.GroupRemoved:Fire(memberKey, groupId, memberRecord.Ref)
	self:_PruneMemberRecordIfEmpty(memberKey)

	return true
end

function Manager:SetMemberGroups(memberRef: TMemberRef, groupIds: { TGroupId }): { TGroupId }
	self:_AssertAlive()
	local normalizedGroupIds = Validation.NormalizeGroupIdArray(groupIds)

	local memberKey = self:GetMemberKey(memberRef)
	local memberRecord = self:_RequireMemberRecord(memberKey)
	local nextGroupSet = Validation.GroupArrayToSet(normalizedGroupIds)

	for existingGroupId in pairs(memberRecord.GroupIds) do
		if nextGroupSet[existingGroupId] ~= true then
			local groupMembers = self._memberKeysByGroupId[existingGroupId]
			if groupMembers ~= nil then
				groupMembers[memberKey] = nil
				if next(groupMembers) == nil then
					self._memberKeysByGroupId[existingGroupId] = nil
				end
			end
		end
	end

	for groupId in pairs(nextGroupSet) do
		self._memberKeysByGroupId[groupId] = self._memberKeysByGroupId[groupId] or {}
		self._memberKeysByGroupId[groupId][memberKey] = true
	end

	memberRecord.GroupIds = nextGroupSet
	memberRecord.Ref = memberRef
	self.GroupSetChanged:Fire(memberKey, normalizedGroupIds, memberRef)
	self:_PruneMemberRecordIfEmpty(memberKey)

	return Validation.CloneFrozen(normalizedGroupIds)
end

function Manager:IsMemberInGroup(memberRef: TMemberRef, groupId: TGroupId): boolean
	Validation.ValidateGroupId(groupId)
	local memberRecord = self:_GetMemberRecordOrNil(memberRef)
	return memberRecord ~= nil and memberRecord.GroupIds[groupId] == true
end

function Manager:ListMemberGroups(memberRef: TMemberRef): { TGroupId }
	local memberRecord = self:_GetMemberRecordOrNil(memberRef)
	if memberRecord == nil then
		return {}
	end

	return Validation.GroupSetToSortedArray(memberRecord.GroupIds)
end

function Manager:ListGroupMembers(groupId: TGroupId): { TRegisteredMember }
	Validation.ValidateGroupId(groupId)
	return self:_BuildRegisteredMembers(self._memberKeysByGroupId[groupId])
end

function Manager:GetMemberCount(teamId: TTeamId): number
	Validation.ValidateTeamId(teamId)
	self:_RequireTeam(teamId)

	local memberKeys = self._memberKeysByTeamId[teamId]
	local count = 0
	if memberKeys == nil then
		return 0
	end

	for _ in pairs(memberKeys) do
		count += 1
	end

	return count
end

function Manager:HasMembers(teamId: TTeamId): boolean
	return self:GetMemberCount(teamId) > 0
end

function Manager:IsTeamEmpty(teamId: TTeamId): boolean
	return self:GetMemberCount(teamId) == 0
end

function Manager:IsSameTeam(leftRef: TMemberRef, rightRef: TMemberRef): boolean
	local leftTeamId = self:_GetAssignedTeamId(leftRef)
	local rightTeamId = self:_GetAssignedTeamId(rightRef)
	return leftTeamId ~= nil and leftTeamId == rightTeamId
end

function Manager:GetRelationship(leftRef: TMemberRef, rightRef: TMemberRef): TRelationship?
	local leftTeamId = self:_GetAssignedTeamId(leftRef)
	local rightTeamId = self:_GetAssignedTeamId(rightRef)
	if leftTeamId == nil or rightTeamId == nil then
		return nil
	end

	return self:GetRelationshipByTeamIds(leftTeamId, rightTeamId)
end

function Manager:AreAllies(leftRef: TMemberRef, rightRef: TMemberRef): boolean
	return self:GetRelationship(leftRef, rightRef) == Relationships.Relationship.Ally
end

function Manager:AreNeutral(leftRef: TMemberRef, rightRef: TMemberRef): boolean
	return self:GetRelationship(leftRef, rightRef) == Relationships.Relationship.Neutral
end

function Manager:AreHostile(leftRef: TMemberRef, rightRef: TMemberRef): boolean
	return self:GetRelationship(leftRef, rightRef) == Relationships.Relationship.Hostile
end

function Manager:EnsureRobloxTeam(teamId: TTeamId): Team?
	Validation.ValidateTeamId(teamId)
	local definition = self:_RequireTeam(teamId)
	if not RobloxTeamsAdapter.ShouldSyncPlayer(definition) then
		return nil
	end

	return RobloxTeamsAdapter.EnsureTeam(definition)
end

function Manager:ClearRobloxProjection(teamId: TTeamId): ()
	Validation.ValidateTeamId(teamId)
	local definition = self:_RequireTeam(teamId)
	local memberKeys = self._memberKeysByTeamId[teamId]

	if memberKeys ~= nil then
		for memberKey in pairs(memberKeys) do
			local memberRecord = self._membersByKey[memberKey]
			if memberRecord ~= nil and memberRecord.Ref ~= nil then
				self:_ClearMemberProjection(memberRecord.Ref)
			end
		end
	end

	RobloxTeamsAdapter.RemoveTeam(definition)
end

function Manager:SyncPlayerTeam(player: Player): ()
	self:_AssertAlive()

	local teamDefinition = self:GetMemberTeam(player)
	if teamDefinition == nil then
		RobloxTeamsAdapter.ClearPlayer(player)
		return
	end

	RobloxTeamsAdapter.SyncPlayer(player, teamDefinition)
end

function Manager:ResyncAllPlayers(): ()
	self:_AssertAlive()

	for _, player in ipairs(Players:GetPlayers()) do
		self:SyncPlayerTeam(player)
	end
end

function Manager:ExportState(): TTeamServiceSnapshot
	self:_AssertAlive()
	return StateCodec.Export(self._teamsById, self._relationships, self._membersByKey)
end

function Manager:ImportState(snapshot: TTeamServiceSnapshot, options: TTeamImportOptions?): TStateImportSummary
	self:_AssertAlive()
	Validation.ValidateImportOptions(options)

	local teamsById, relationships, membersByKey, importSummary = StateCodec.Decode(snapshot)
	self:ResyncAllPlayers()
	self:_ClearState()

	self._teamsById = teamsById
	self._relationships = relationships
	self._membersByKey = membersByKey

	for teamId in pairs(self._teamsById) do
		self._memberKeysByTeamId[teamId] = self._memberKeysByTeamId[teamId] or {}
	end

	for memberKey, memberRecord in pairs(self._membersByKey) do
		if memberRecord.PrimaryTeamId ~= nil then
			self._memberKeysByTeamId[memberRecord.PrimaryTeamId] = self._memberKeysByTeamId[memberRecord.PrimaryTeamId] or {}
			self._memberKeysByTeamId[memberRecord.PrimaryTeamId][memberKey] = true
		end

		for groupId in pairs(memberRecord.GroupIds) do
			self._memberKeysByGroupId[groupId] = self._memberKeysByGroupId[groupId] or {}
			self._memberKeysByGroupId[groupId][memberKey] = true
		end
	end

	self:ResyncAllPlayers()
	self.StateImported:Fire(importSummary)

	return importSummary
end

function Manager:ResolveOwnershipMembership(input: TResolvedOwnershipAdapterInput): TResolvedOwnershipMembership
	return OwnershipAdapter.Resolve(input)
end

function Manager:Destroy(): ()
	if self._isDestroyed then
		return
	end

	self:ResyncAllPlayers()
	self:_ClearState()

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	self.TeamCreated:DisconnectAll()
	self.TeamRemoved:DisconnectAll()
	self.TeamUpdated:DisconnectAll()
	self.RelationshipChanged:DisconnectAll()
	self.MemberAssigned:DisconnectAll()
	self.MemberUnassigned:DisconnectAll()
	self.MemberSwitched:DisconnectAll()
	self.GroupAssigned:DisconnectAll()
	self.GroupRemoved:DisconnectAll()
	self.GroupSetChanged:DisconnectAll()
	self.StateImported:DisconnectAll()

	self._isDestroyed = true
end

function Manager:_AssertAlive(): ()
	assert(not self._isDestroyed, "TeamService manager has already been destroyed")
end

function Manager:_RequireTeam(teamId: TTeamId): TResolvedTeamDefinition
	local definition = self._teamsById[teamId]
	assert(definition ~= nil, (`TeamService team "%s" is not registered`):format(teamId))
	return definition
end

function Manager:_GetMemberRecordOrNil(memberRef: TMemberRef): TStoredMemberRecord?
	local memberKey = self:GetMemberKey(memberRef)
	return self._membersByKey[memberKey]
end

function Manager:_RequireMemberRecord(memberKey: TMemberKey): TStoredMemberRecord
	local memberRecord = self._membersByKey[memberKey]
	assert(memberRecord ~= nil, (`TeamService member "%s" is not registered`):format(memberKey))
	return memberRecord
end

function Manager:_GetOrCreateMemberRecord(memberKey: TMemberKey, memberRef: TMemberRef): TStoredMemberRecord
	local memberRecord = self._membersByKey[memberKey]
	if memberRecord ~= nil then
		return memberRecord
	end

	memberRecord = {
		PrimaryTeamId = nil,
		GroupIds = {},
		Ref = memberRef,
	}
	self._membersByKey[memberKey] = memberRecord

	return memberRecord
end

function Manager:_RemoveMemberFromTeamIndex(memberKey: TMemberKey, teamId: TTeamId): ()
	local memberKeys = self._memberKeysByTeamId[teamId]
	if memberKeys == nil then
		return
	end

	memberKeys[memberKey] = nil
end

function Manager:_ForceUnassignTeamMembers(teamId: TTeamId): ()
	local memberKeys = self._memberKeysByTeamId[teamId]
	if memberKeys == nil then
		return
	end

	local memberKeysToRemove = {}
	for memberKey in pairs(memberKeys) do
		memberKeysToRemove[#memberKeysToRemove + 1] = memberKey
	end

	for _, memberKey in ipairs(memberKeysToRemove) do
		local memberRecord = self._membersByKey[memberKey]
		if memberRecord ~= nil then
			local memberRef = memberRecord.Ref
			if memberRef == nil then
				memberRef = memberKey
			end
			self:UnassignMember(memberRef)
		end
	end
end

function Manager:_GetAssignedTeamId(memberRef: TMemberRef): TTeamId?
	local memberRecord = self:_GetMemberRecordOrNil(memberRef)
	if memberRecord == nil then
		return nil
	end

	return memberRecord.PrimaryTeamId
end

function Manager:_SyncMemberProjection(memberRef: TMemberRef, definition: TResolvedTeamDefinition): ()
	if not Resolver.IsPlayer(memberRef) then
		return
	end

	RobloxTeamsAdapter.SyncPlayer(memberRef :: Player, definition)
end

function Manager:_ClearMemberProjection(memberRef: TMemberRef): ()
	if not Resolver.IsPlayer(memberRef) then
		return
	end

	RobloxTeamsAdapter.ClearPlayer(memberRef :: Player)
end

function Manager:_HandlePlayerRemoving(player: Player): ()
	if self._isDestroyed then
		return
	end

	local memberKey = self:GetMemberKey(player)
	local memberRecord = self._membersByKey[memberKey]
	if memberRecord == nil then
		return
	end

	memberRecord.Ref = nil
	if memberRecord.PrimaryTeamId ~= nil then
		self:_RemoveMemberFromTeamIndex(memberKey, memberRecord.PrimaryTeamId)
		memberRecord.PrimaryTeamId = nil
	end

	for groupId in pairs(memberRecord.GroupIds) do
		local groupMembers = self._memberKeysByGroupId[groupId]
		if groupMembers ~= nil then
			groupMembers[memberKey] = nil
			if next(groupMembers) == nil then
				self._memberKeysByGroupId[groupId] = nil
			end
		end
	end

	self._membersByKey[memberKey] = nil
	RobloxTeamsAdapter.ClearPlayer(player)
end

function Manager:_PruneMemberRecordIfEmpty(memberKey: TMemberKey): ()
	local memberRecord = self._membersByKey[memberKey]
	if memberRecord == nil then
		return
	end

	if memberRecord.PrimaryTeamId == nil and next(memberRecord.GroupIds) == nil then
		self._membersByKey[memberKey] = nil
	end
end

function Manager:_BuildRegisteredMembers(memberKeys: { [TMemberKey]: true }?): { TRegisteredMember }
	local memberEntries = {}
	if memberKeys == nil then
		return memberEntries
	end

	for memberKey in pairs(memberKeys) do
		local memberRecord = self._membersByKey[memberKey]
		memberEntries[#memberEntries + 1] = {
			MemberKey = memberKey,
			MemberRef = if memberRecord ~= nil then memberRecord.Ref else nil,
		}
	end

	table.sort(memberEntries, function(leftEntry: TRegisteredMember, rightEntry: TRegisteredMember): boolean
		return leftEntry.MemberKey < rightEntry.MemberKey
	end)

	return memberEntries
end

function Manager:_ResyncPlayersForTeam(teamId: TTeamId): ()
	local definition = self:_RequireTeam(teamId)
	local memberKeys = self._memberKeysByTeamId[teamId]
	if memberKeys == nil then
		return
	end

	for memberKey in pairs(memberKeys) do
		local memberRecord = self._membersByKey[memberKey]
		if memberRecord ~= nil and memberRecord.Ref ~= nil then
			self:_SyncMemberProjection(memberRecord.Ref, definition)
		end
	end
end

function Manager:_ClearState(): ()
	for memberKey, memberRecord in pairs(self._membersByKey) do
		if memberRecord.Ref ~= nil then
			self:_ClearMemberProjection(memberRecord.Ref)
		end
		self._membersByKey[memberKey] = nil
	end

	for teamId, definition in pairs(self._teamsById) do
		self._memberKeysByTeamId[teamId] = nil
		RobloxTeamsAdapter.RemoveTeam(definition)
	end

	table.clear(self._teamsById)
	table.clear(self._membersByKey)
	table.clear(self._memberKeysByTeamId)
	table.clear(self._memberKeysByGroupId)
	table.clear(self._relationships)
end

return table.freeze(Manager)
