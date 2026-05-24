--!strict

local Manager = require(script.Manager)
local Relationships = require(script.Relationships)
local Types = require(script.Types)

export type TTeamId = Types.TTeamId
export type TGroupId = Types.TGroupId
export type TRelationship = Types.TRelationship
export type TMemberKey = Types.TMemberKey
export type TMemberDescriptor = Types.TMemberDescriptor
export type TMemberRef = Types.TMemberRef
export type TTeamRobloxOptions = Types.TTeamRobloxOptions
export type TTeamDefinition = Types.TTeamDefinition
export type TTeamUpdatePatch = Types.TTeamUpdatePatch
export type TTeamManagerConfig = Types.TTeamManagerConfig
export type TTeamRemoveOptions = Types.TTeamRemoveOptions
export type TTeamImportOptions = Types.TTeamImportOptions
export type TRegisteredMember = Types.TRegisteredMember
export type TMemberSnapshot = Types.TMemberSnapshot
export type TTeamServiceSnapshot = Types.TTeamServiceSnapshot
export type TResolvedOwnershipAdapterInput = Types.TResolvedOwnershipAdapterInput
export type TResolvedOwnershipMembership = Types.TResolvedOwnershipMembership
export type TStateImportSummary = Types.TStateImportSummary
export type TTeamManager = Types.TTeamManager

local TeamService = {
	Relationship = Relationships.Relationship,
}

function TeamService.new(config: Types.TTeamManagerConfig?): Types.TTeamManager
	return Manager.new(config)
end

return table.freeze(TeamService)
