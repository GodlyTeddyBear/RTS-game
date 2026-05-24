--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TTeamSummary = TeamTypes.TTeamSummary

local Ensure = Result.Ensure
local Ok = Result.Ok

local RegisterPlayerTeamCommand = {}
RegisterPlayerTeamCommand.__index = RegisterPlayerTeamCommand
setmetatable(RegisterPlayerTeamCommand, BaseCommand)

function RegisterPlayerTeamCommand.new()
	local self = BaseCommand.new("Team", "RegisterPlayerTeam")
	return setmetatable(self, RegisterPlayerTeamCommand)
end

function RegisterPlayerTeamCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_runtimeService", "TeamRuntimeService")
end

function RegisterPlayerTeamCommand:Execute(player: Player): Result.Result<TTeamSummary>
	return Result.Catch(function()
		Ensure(typeof(player) == "Instance" and player:IsA("Player"), "InvalidPlayer", Errors.INVALID_PLAYER)
		return Ok(self._runtimeService:EnsurePlayerTeam(player))
	end, self:_Label())
end

return RegisterPlayerTeamCommand
