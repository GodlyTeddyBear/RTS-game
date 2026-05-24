--!strict

local Relationships = require(script.Parent.Relationships)
local Types = require(script.Parent.Types)

type TGroupId = Types.TGroupId
type TMemberKey = Types.TMemberKey
type TMemberRef = Types.TMemberRef
type TRelationship = Types.TRelationship
type TResolvedTeamDefinition = Types.TResolvedTeamDefinition
type TResolvedTeamManagerConfig = Types.TResolvedTeamManagerConfig
type TTeamDefinition = Types.TTeamDefinition
type TTeamId = Types.TTeamId
type TTeamImportOptions = Types.TTeamImportOptions
type TTeamManagerConfig = Types.TTeamManagerConfig
type TTeamRemoveOptions = Types.TTeamRemoveOptions
type TTeamRobloxOptions = Types.TTeamRobloxOptions
type TTeamUpdatePatch = Types.TTeamUpdatePatch

local Validation = {}

local function _CloneDeep(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local cloned = {}
	for key, nestedValue in pairs(value) do
		cloned[_CloneDeep(key)] = _CloneDeep(nestedValue)
	end

	return cloned
end

local function _FreezeDeep(value: any): any
	if type(value) ~= "table" then
		return value
	end

	for _, nestedValue in pairs(value) do
		if type(nestedValue) == "table" and not table.isfrozen(nestedValue) then
			_FreezeDeep(nestedValue)
		end
	end

	if not table.isfrozen(value) then
		table.freeze(value)
	end

	return value
end

local function _AssertNonEmptyString(value: any, name: string): ()
	assert(type(value) == "string" and value ~= "", (`TeamService expected %s to be a non-empty string`):format(name))
end

local function _NormalizeRobloxOptions(options: TTeamRobloxOptions?): Types.TResolvedTeamRobloxOptions
	if options ~= nil then
		assert(options.SyncPlayers == nil or type(options.SyncPlayers) == "boolean", "TeamService expected Roblox.SyncPlayers to be a boolean when provided")
		assert(options.Name == nil or type(options.Name) == "string", "TeamService expected Roblox.Name to be a string when provided")
		assert(
			options.TeamColor == nil or typeof(options.TeamColor) == "BrickColor",
			"TeamService expected Roblox.TeamColor to be a BrickColor when provided"
		)
		assert(
			options.AutoAssignable == nil or type(options.AutoAssignable) == "boolean",
			"TeamService expected Roblox.AutoAssignable to be a boolean when provided"
		)
	end

	return {
		SyncPlayers = if options ~= nil and options.SyncPlayers ~= nil then options.SyncPlayers else true,
		Name = if options ~= nil then options.Name else nil,
		TeamColor = if options ~= nil then options.TeamColor else nil,
		AutoAssignable = if options ~= nil and options.AutoAssignable ~= nil then options.AutoAssignable else false,
	}
end

function Validation.CloneDeep(value: any): any
	return _CloneDeep(value)
end

function Validation.FreezeDeep(value: any): any
	return _FreezeDeep(value)
end

function Validation.CloneFrozen<T>(value: T): T
	return _FreezeDeep(_CloneDeep(value))
end

function Validation.IsSupportedMemberRef(value: any): boolean
	if typeof(value) == "Instance" then
		return true
	end

	if type(value) == "string" then
		return value ~= ""
	end

	if type(value) ~= "table" then
		return false
	end

	return type(value.Kind) == "string" and value.Kind ~= "" and type(value.Id) == "string" and value.Id ~= ""
end

function Validation.NormalizeManagerConfig(config: TTeamManagerConfig?): TResolvedTeamManagerConfig
	if config == nil then
		return table.freeze({
			ResolveMemberKey = nil,
			ResolveMemberLabel = nil,
		})
	end

	assert(type(config) == "table", "TeamService expected manager config to be a table")
	assert(config.ResolveMemberKey == nil or type(config.ResolveMemberKey) == "function", "TeamService expected ResolveMemberKey to be a function")
	assert(config.ResolveMemberLabel == nil or type(config.ResolveMemberLabel) == "function", "TeamService expected ResolveMemberLabel to be a function")

	return table.freeze({
		ResolveMemberKey = config.ResolveMemberKey,
		ResolveMemberLabel = config.ResolveMemberLabel,
	})
end

function Validation.NormalizeTeamDefinition(definition: TTeamDefinition): TResolvedTeamDefinition
	assert(type(definition) == "table", "TeamService expected team definition to be a table")
	_AssertNonEmptyString(definition.TeamId, "TeamId")
	assert(definition.DisplayName == nil or type(definition.DisplayName) == "string", "TeamService expected DisplayName to be a string when provided")
	assert(definition.Metadata == nil or type(definition.Metadata) == "table", "TeamService expected Metadata to be a table when provided")
	assert(definition.Roblox == nil or type(definition.Roblox) == "table", "TeamService expected Roblox to be a table when provided")

	local metadata = nil
	if definition.Metadata ~= nil then
		metadata = Validation.CloneFrozen(definition.Metadata)
	end

	return Validation.CloneFrozen({
		TeamId = definition.TeamId,
		DisplayName = definition.DisplayName,
		Metadata = metadata,
		Roblox = _NormalizeRobloxOptions(definition.Roblox),
	})
end

function Validation.ApplyTeamPatch(definition: TResolvedTeamDefinition, patch: TTeamUpdatePatch): TResolvedTeamDefinition
	assert(type(patch) == "table", "TeamService expected team patch to be a table")
	assert(patch.TeamId == nil, "TeamService UpdateTeam does not allow TeamId changes")
	assert(patch.DisplayName == nil or type(patch.DisplayName) == "string", "TeamService expected patch DisplayName to be a string when provided")
	assert(patch.Metadata == nil or type(patch.Metadata) == "table", "TeamService expected patch Metadata to be a table when provided")
	assert(patch.Roblox == nil or type(patch.Roblox) == "table", "TeamService expected patch Roblox to be a table when provided")

	local nextRobloxOptions = {
		SyncPlayers = definition.Roblox.SyncPlayers,
		Name = definition.Roblox.Name,
		TeamColor = definition.Roblox.TeamColor,
		AutoAssignable = definition.Roblox.AutoAssignable,
	}
	if patch.Roblox ~= nil then
		assert(
			patch.Roblox.SyncPlayers == nil or type(patch.Roblox.SyncPlayers) == "boolean",
			"TeamService expected patch Roblox.SyncPlayers to be a boolean when provided"
		)
		assert(
			patch.Roblox.Name == nil or type(patch.Roblox.Name) == "string",
			"TeamService expected patch Roblox.Name to be a string when provided"
		)
		assert(
			patch.Roblox.TeamColor == nil or typeof(patch.Roblox.TeamColor) == "BrickColor",
			"TeamService expected patch Roblox.TeamColor to be a BrickColor when provided"
		)
		assert(
			patch.Roblox.AutoAssignable == nil or type(patch.Roblox.AutoAssignable) == "boolean",
			"TeamService expected patch Roblox.AutoAssignable to be a boolean when provided"
		)

		if patch.Roblox.SyncPlayers ~= nil then
			nextRobloxOptions.SyncPlayers = patch.Roblox.SyncPlayers
		end
		if patch.Roblox.Name ~= nil then
			nextRobloxOptions.Name = patch.Roblox.Name
		end
		if patch.Roblox.TeamColor ~= nil then
			nextRobloxOptions.TeamColor = patch.Roblox.TeamColor
		end
		if patch.Roblox.AutoAssignable ~= nil then
			nextRobloxOptions.AutoAssignable = patch.Roblox.AutoAssignable
		end
	end

	local nextMetadata = definition.Metadata
	if patch.Metadata ~= nil then
		nextMetadata = Validation.CloneFrozen(patch.Metadata)
	end

	return Validation.CloneFrozen({
		TeamId = definition.TeamId,
		DisplayName = if patch.DisplayName ~= nil then patch.DisplayName else definition.DisplayName,
		Metadata = nextMetadata,
		Roblox = nextRobloxOptions,
	})
end

function Validation.ValidateTeamId(teamId: TTeamId): ()
	_AssertNonEmptyString(teamId, "teamId")
end

function Validation.ValidateGroupId(groupId: TGroupId): ()
	_AssertNonEmptyString(groupId, "groupId")
end

function Validation.ValidateMemberKey(memberKey: TMemberKey): ()
	_AssertNonEmptyString(memberKey, "memberKey")
end

function Validation.ValidateRelationship(relationship: TRelationship): ()
	assert(Relationships.IsValidRelationship(relationship), "TeamService expected a valid relationship value")
end

function Validation.ValidateRemoveOptions(options: TTeamRemoveOptions?): ()
	assert(options == nil or type(options) == "table", "TeamService expected remove options to be a table when provided")
	if options ~= nil then
		assert(options.Force == nil or type(options.Force) == "boolean", "TeamService expected remove options Force to be a boolean")
	end
end

function Validation.ValidateImportOptions(options: TTeamImportOptions?): ()
	assert(options == nil or type(options) == "table", "TeamService expected import options to be a table when provided")
	if options ~= nil then
		assert(options.Replace == nil or type(options.Replace) == "boolean", "TeamService expected import options Replace to be a boolean")
		assert(options.Replace ~= false, "TeamService v2 import only supports replace-all semantics")
	end
end

function Validation.NormalizeGroupIdArray(groupIds: { TGroupId }): { TGroupId }
	assert(type(groupIds) == "table", "TeamService expected groupIds to be an array")

	local uniqueGroupIds = {}
	local groupIdsByValue = {}
	for _, groupId in ipairs(groupIds) do
		Validation.ValidateGroupId(groupId)
		if groupIdsByValue[groupId] == nil then
			groupIdsByValue[groupId] = true
			uniqueGroupIds[#uniqueGroupIds + 1] = groupId
		end
	end

	table.sort(uniqueGroupIds)
	return uniqueGroupIds
end

function Validation.GroupArrayToSet(groupIds: { TGroupId }): { [TGroupId]: true }
	local groupSet = {}
	for _, groupId in ipairs(Validation.NormalizeGroupIdArray(groupIds)) do
		groupSet[groupId] = true
	end
	return groupSet
end

function Validation.GroupSetToSortedArray(groupSet: { [TGroupId]: true }): { TGroupId }
	local groupIds = {}
	for groupId in pairs(groupSet) do
		groupIds[#groupIds + 1] = groupId
	end
	table.sort(groupIds)
	return groupIds
end

function Validation.BuildOwnerGroupId(ownerKind: string, ownerId: string): string
	_AssertNonEmptyString(ownerKind, "ownerKind")
	_AssertNonEmptyString(ownerId, "ownerId")
	return ownerKind .. ":" .. ownerId
end

return table.freeze(Validation)
