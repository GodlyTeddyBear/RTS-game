--!strict

local Teams = game:GetService("Teams")

local Types = require(script.Parent.Types)

type TResolvedTeamDefinition = Types.TResolvedTeamDefinition

local RobloxTeamsAdapter = {}

local function _ResolveTeamInstanceName(definition: TResolvedTeamDefinition): string
	local robloxOptions = definition.Roblox
	if robloxOptions.Name ~= nil and robloxOptions.Name ~= "" then
		return robloxOptions.Name
	end

	if definition.DisplayName ~= nil and definition.DisplayName ~= "" then
		return definition.DisplayName
	end

	return definition.TeamId
end

function RobloxTeamsAdapter.GetTeamName(definition: TResolvedTeamDefinition): string
	return _ResolveTeamInstanceName(definition)
end

function RobloxTeamsAdapter.ShouldSyncPlayer(definition: TResolvedTeamDefinition): boolean
	return definition.Roblox.SyncPlayers ~= false
end

function RobloxTeamsAdapter.FindTeam(definition: TResolvedTeamDefinition): Team?
	local existingTeam = Teams:FindFirstChild(_ResolveTeamInstanceName(definition))
	if existingTeam == nil then
		return nil
	end

	assert(existingTeam:IsA("Team"), (`TeamService expected "%s" under Teams to be a Team instance`):format(existingTeam.Name))
	return existingTeam :: Team
end

function RobloxTeamsAdapter.EnsureTeam(definition: TResolvedTeamDefinition): Team
	local teamInstance = RobloxTeamsAdapter.FindTeam(definition)
	if teamInstance == nil then
		teamInstance = Instance.new("Team")
		teamInstance.Name = _ResolveTeamInstanceName(definition)
		teamInstance.Parent = Teams
	end

	teamInstance.AutoAssignable = definition.Roblox.AutoAssignable
	if definition.Roblox.TeamColor ~= nil then
		teamInstance.TeamColor = definition.Roblox.TeamColor
	end

	return teamInstance
end

function RobloxTeamsAdapter.SyncPlayer(player: Player, definition: TResolvedTeamDefinition): ()
	if not RobloxTeamsAdapter.ShouldSyncPlayer(definition) then
		player.Team = nil
		return
	end

	player.Team = RobloxTeamsAdapter.EnsureTeam(definition)
end

function RobloxTeamsAdapter.ClearPlayer(player: Player): ()
	player.Team = nil
end

function RobloxTeamsAdapter.RemoveTeam(definition: TResolvedTeamDefinition): ()
	local teamInstance = RobloxTeamsAdapter.FindTeam(definition)
	if teamInstance ~= nil then
		teamInstance:Destroy()
	end
end

return table.freeze(RobloxTeamsAdapter)
