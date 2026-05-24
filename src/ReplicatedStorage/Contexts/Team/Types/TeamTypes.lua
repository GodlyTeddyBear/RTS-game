--!strict

--[=[
	@class TeamTypes
	Defines shared team query and member-handle shapes.
	@server
	@client
]=]
local TeamTypes = {}

export type TMemberKind = "Player" | "Unit" | "Structure" | "Enemy"
export type TRelationship = "Ally" | "Neutral" | "Hostile"

export type TMemberHandle = {
	Kind: TMemberKind,
	Id: string,
}

export type TTeamSummary = {
	TeamId: string,
	DisplayName: string?,
	Metadata: { [string]: any }?,
}

export type TRelationshipResult = {
	Relationship: TRelationship?,
	LeftTeam: TTeamSummary?,
	RightTeam: TTeamSummary?,
}

local MEMBER_KINDS: { [string]: true } = table.freeze({
	Player = true,
	Unit = true,
	Structure = true,
	Enemy = true,
})

local RELATIONSHIPS: { [string]: true } = table.freeze({
	Ally = true,
	Neutral = true,
	Hostile = true,
})

function TeamTypes.IsMemberKind(value: any): boolean
	return type(value) == "string" and MEMBER_KINDS[value] == true
end

function TeamTypes.IsRelationship(value: any): boolean
	return type(value) == "string" and RELATIONSHIPS[value] == true
end

function TeamTypes.IsMemberHandle(value: any): boolean
	return type(value) == "table"
		and TeamTypes.IsMemberKind(value.Kind)
		and type(value.Id) == "string"
		and value.Id ~= ""
end

function TeamTypes.BuildMemberHandle(kind: TMemberKind, id: string): TMemberHandle
	assert(TeamTypes.IsMemberKind(kind), "TeamTypes expected a valid member kind")
	assert(type(id) == "string" and id ~= "", "TeamTypes expected id to be a non-empty string")
	return table.freeze({
		Kind = kind,
		Id = id,
	})
end

return table.freeze(TeamTypes)
