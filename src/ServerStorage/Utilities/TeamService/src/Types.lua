--!strict

export type TTeamId = string
export type TGroupId = string
export type TRelationship = "Ally" | "Neutral" | "Hostile"
export type TMemberKey = string

export type TMemberDescriptor = {
	Kind: string,
	Id: string,
	Instance: Instance?,
}

export type TMemberRef = Player | string | Instance | TMemberDescriptor

export type TTeamRobloxOptions = {
	SyncPlayers: boolean?,
	Name: string?,
	TeamColor: BrickColor?,
	AutoAssignable: boolean?,
}

export type TTeamDefinition = {
	TeamId: TTeamId,
	DisplayName: string?,
	Metadata: { [string]: any }?,
	Roblox: TTeamRobloxOptions?,
}

export type TTeamUpdatePatch = {
	DisplayName: string?,
	Metadata: { [string]: any }?,
	Roblox: TTeamRobloxOptions?,
	TeamId: string?,
}

export type TResolvedTeamRobloxOptions = {
	SyncPlayers: boolean,
	Name: string?,
	TeamColor: BrickColor?,
	AutoAssignable: boolean,
}

export type TResolvedTeamDefinition = {
	TeamId: TTeamId,
	DisplayName: string?,
	Metadata: { [string]: any }?,
	Roblox: TResolvedTeamRobloxOptions,
}

export type TTeamManagerConfig = {
	ResolveMemberKey: ((memberRef: TMemberRef) -> string?)?,
	ResolveMemberLabel: ((memberRef: TMemberRef) -> string?)?,
}

export type TResolvedTeamManagerConfig = {
	ResolveMemberKey: ((memberRef: TMemberRef) -> string?)?,
	ResolveMemberLabel: ((memberRef: TMemberRef) -> string?)?,
}

export type TTeamRemoveOptions = {
	Force: boolean?,
}

export type TTeamImportOptions = {
	Replace: boolean?,
}

export type TStoredMemberRecord = {
	PrimaryTeamId: TTeamId?,
	GroupIds: { [TGroupId]: true },
	Ref: TMemberRef?,
}

export type TRegisteredMember = {
	MemberKey: TMemberKey,
	MemberRef: TMemberRef?,
}

export type TMemberSnapshot = {
	MemberKey: TMemberKey,
	PrimaryTeamId: TTeamId?,
	GroupIds: { TGroupId },
	MemberRef: TMemberRef?,
}

export type TTeamServiceSnapshot = {
	Teams: { TResolvedTeamDefinition },
	Relationships: { [TTeamId]: { [TTeamId]: TRelationship } },
	Members: { TMemberSnapshot },
}

export type TResolvedOwnershipAdapterInput = {
	Faction: string?,
	OwnerKind: string?,
	OwnerId: string?,
}

export type TResolvedOwnershipMembership = {
	PrimaryTeamId: TTeamId?,
	GroupIds: { TGroupId },
}

export type TStateImportSummary = {
	TeamCount: number,
	MemberCount: number,
	GroupCount: number,
}

export type TSignal = {
	Connect: (self: TSignal, callback: (...any) -> ()) -> any,
	Once: (self: TSignal, callback: (...any) -> ()) -> any,
	Fire: (self: TSignal, ...any) -> (),
	Wait: (self: TSignal) -> ...any,
	DisconnectAll: (self: TSignal) -> (),
}

export type TTeamManager = {
	TeamCreated: TSignal,
	TeamRemoved: TSignal,
	TeamUpdated: TSignal,
	RelationshipChanged: TSignal,
	MemberAssigned: TSignal,
	MemberUnassigned: TSignal,
	MemberSwitched: TSignal,
	GroupAssigned: TSignal,
	GroupRemoved: TSignal,
	GroupSetChanged: TSignal,
	StateImported: TSignal,

	RegisterTeam: (self: TTeamManager, definition: TTeamDefinition) -> TResolvedTeamDefinition,
	RegisterTeams: (self: TTeamManager, definitions: { TTeamDefinition }) -> { TResolvedTeamDefinition },
	RemoveTeam: (self: TTeamManager, teamId: TTeamId, options: TTeamRemoveOptions?) -> TResolvedTeamDefinition,
	UpdateTeam: (self: TTeamManager, teamId: TTeamId, patch: TTeamUpdatePatch) -> TResolvedTeamDefinition,
	HasTeam: (self: TTeamManager, teamId: TTeamId) -> boolean,
	GetTeam: (self: TTeamManager, teamId: TTeamId) -> TResolvedTeamDefinition?,
	ListTeams: (self: TTeamManager) -> { TResolvedTeamDefinition },
	SetRelationship: (self: TTeamManager, teamA: TTeamId, teamB: TTeamId, relationship: TRelationship) -> TRelationship,
	GetRelationshipByTeamIds: (self: TTeamManager, teamA: TTeamId, teamB: TTeamId) -> TRelationship?,
	AssignMember: (self: TTeamManager, memberRef: TMemberRef, teamId: TTeamId) -> TResolvedTeamDefinition,
	AssignMembers: (self: TTeamManager, memberRefs: { TMemberRef }, teamId: TTeamId) -> number,
	UnassignMember: (self: TTeamManager, memberRef: TMemberRef) -> TTeamId?,
	UnassignMembers: (self: TTeamManager, memberRefs: { TMemberRef }) -> number,
	SwitchMember: (self: TTeamManager, memberRef: TMemberRef, nextTeamId: TTeamId) -> TResolvedTeamDefinition,
	GetMemberTeam: (self: TTeamManager, memberRef: TMemberRef) -> TResolvedTeamDefinition?,
	GetMemberKey: (self: TTeamManager, memberRef: TMemberRef) -> TMemberKey,
	ListMembers: (self: TTeamManager, teamId: TTeamId) -> { TRegisteredMember },
	AddMemberToGroup: (self: TTeamManager, memberRef: TMemberRef, groupId: TGroupId) -> boolean,
	RemoveMemberFromGroup: (self: TTeamManager, memberRef: TMemberRef, groupId: TGroupId) -> boolean,
	SetMemberGroups: (self: TTeamManager, memberRef: TMemberRef, groupIds: { TGroupId }) -> { TGroupId },
	IsMemberInGroup: (self: TTeamManager, memberRef: TMemberRef, groupId: TGroupId) -> boolean,
	ListMemberGroups: (self: TTeamManager, memberRef: TMemberRef) -> { TGroupId },
	ListGroupMembers: (self: TTeamManager, groupId: TGroupId) -> { TRegisteredMember },
	GetMemberCount: (self: TTeamManager, teamId: TTeamId) -> number,
	HasMembers: (self: TTeamManager, teamId: TTeamId) -> boolean,
	IsTeamEmpty: (self: TTeamManager, teamId: TTeamId) -> boolean,
	IsSameTeam: (self: TTeamManager, leftRef: TMemberRef, rightRef: TMemberRef) -> boolean,
	GetRelationship: (self: TTeamManager, leftRef: TMemberRef, rightRef: TMemberRef) -> TRelationship?,
	AreAllies: (self: TTeamManager, leftRef: TMemberRef, rightRef: TMemberRef) -> boolean,
	AreNeutral: (self: TTeamManager, leftRef: TMemberRef, rightRef: TMemberRef) -> boolean,
	AreHostile: (self: TTeamManager, leftRef: TMemberRef, rightRef: TMemberRef) -> boolean,
	EnsureRobloxTeam: (self: TTeamManager, teamId: TTeamId) -> Team?,
	ClearRobloxProjection: (self: TTeamManager, teamId: TTeamId) -> (),
	SyncPlayerTeam: (self: TTeamManager, player: Player) -> (),
	ResyncAllPlayers: (self: TTeamManager) -> (),
	ExportState: (self: TTeamManager) -> TTeamServiceSnapshot,
	ImportState: (self: TTeamManager, snapshot: TTeamServiceSnapshot, options: TTeamImportOptions?) -> TStateImportSummary,
	ResolveOwnershipMembership: (self: TTeamManager, input: TResolvedOwnershipAdapterInput) -> TResolvedOwnershipMembership,
	Destroy: (self: TTeamManager) -> (),
}

local Types = {}

return Types
