--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

-- Domain Policies
local NPCCommandPolicy = require(script.Parent.PlayerCommandDomain.Policies.NPCCommandPolicy)
local AttackTargetPolicy = require(script.Parent.PlayerCommandDomain.Policies.AttackTargetPolicy)

-- Infrastructure Services
local CommandWriteService = require(script.Parent.Infrastructure.Services.CommandWriteService)

-- Application Services
local ProcessPlayerCommand = require(script.Parent.Application.Commands.ProcessPlayerCommand)
local ProcessToggleMode = require(script.Parent.Application.Commands.ProcessToggleMode)
local ClearAllCommands = require(script.Parent.Application.Commands.ClearAllCommands)

--[=[
    @class PlayerCommandContext
    Knit service that exposes player NPC commanding and mode-toggling to clients and other server contexts.
    @server
]=]
local PlayerCommandContext = Knit.CreateService({
	Name = "PlayerCommandContext",
	Client = {
		PlayerCommand = Knit.CreateSignal(),
		ToggleMode = Knit.CreateSignal(),
	},
})

---
-- Knit Lifecycle
---

function PlayerCommandContext:KnitInit()
	self._registry = Registry.new("Server")

	-- Domain Policies
	self._registry:Register("NPCCommandPolicy", NPCCommandPolicy.new(), "Domain")
	self._registry:Register("AttackTargetPolicy", AttackTargetPolicy.new(), "Domain")

	-- Infrastructure Services
	self._registry:Register("CommandWriteService", CommandWriteService.new(), "Infrastructure")

	-- Application Services
	self._registry:Register("ProcessPlayerCommand", ProcessPlayerCommand.new(), "Application")
	self._registry:Register("ProcessToggleMode", ProcessToggleMode.new(), "Application")
	self._registry:Register("ClearAllCommands", ClearAllCommands.new(), "Application")

	-- Init resolves intra-context deps; cross-context deps wired in KnitStart
	self._registry:InitAll()

end

function PlayerCommandContext:KnitStart()
	-- Cross-context dependencies
	local NPCContext = Knit.GetService("NPCContext")
	local CombatContext = Knit.GetService("CombatContext")

	local entityFactory = Try(NPCContext:GetEntityFactory())
	local combatLoopService = Try(CombatContext:GetCombatLoopService())

	-- Register cross-context raw values so Start() methods can pull them
	self._registry:Register("NPCEntityFactory", entityFactory)
	self._registry:Register("CombatLoopService", combatLoopService)

	-- Start all wires cross-context deps into services
	self._registry:StartAll()

	-- Cache refs
	self.CommandWriteService = self._registry:Get("CommandWriteService")
	self.ProcessPlayerCommandService = self._registry:Get("ProcessPlayerCommand")
	self.ProcessToggleModeService = self._registry:Get("ProcessToggleMode")
	self.ClearAllCommandsService = self._registry:Get("ClearAllCommands")

	-- Wire client remotes
	self.Client.PlayerCommand:Connect(function(player: Player, payload: any)
		self:_OnPlayerCommand(player.UserId, payload)
	end)

	self.Client.ToggleMode:Connect(function(player: Player, payload: any)
		self:_OnToggleMode(player.UserId, payload)
	end)

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		self.ProcessPlayerCommandService:CleanupUser(player.UserId)
	end)

	print("PlayerCommandContext started")
end

---
-- Client Remote Handlers
---

function PlayerCommandContext:_OnPlayerCommand(userId: number, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local commandType = payload.CommandType
	local npcIds = payload.NPCIds
	local data = payload.Data

	if type(commandType) ~= "string" or type(npcIds) ~= "table" or type(data) ~= "table" then
		return
	end

	return Catch(
		self.ProcessPlayerCommandService.Execute,
		"PlayerCommand:_OnPlayerCommand",
		nil,
		self.ProcessPlayerCommandService,
		userId,
		commandType,
		npcIds,
		data
	)
end

function PlayerCommandContext:_OnToggleMode(userId: number, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local npcIds = payload.NPCIds
	if type(npcIds) ~= "table" then
		return
	end

	return Catch(
		self.ProcessToggleModeService.Execute,
		"PlayerCommand:_OnToggleMode",
		nil,
		self.ProcessToggleModeService,
		userId,
		npcIds
	)
end

---
-- Server-to-Server API
---

--[=[
    Clears all player commands for a user. Called by `CombatContext` during wave transitions or combat end.
    @within PlayerCommandContext
    @param userId number -- The player's user ID
    @return Result<any> -- `Ok(nil)` on success
]=]
function PlayerCommandContext:ClearCommandsForUser(userId: number): Result.Result<any>
	return Catch(function()
		return self.ClearAllCommandsService:Execute(userId)
	end, "PlayerCommand:ClearCommandsForUser")
end

--[=[
    Returns the `CommandWriteService` instance for cross-context use (e.g. reading control mode in `ProcessCombatTick`).
    @within PlayerCommandContext
    @return Result<any> -- `Ok(CommandWriteService)`
]=]
function PlayerCommandContext:GetCommandWriteService(): Result.Result<any>
	return Ok(self.CommandWriteService)
end

WrapContext(PlayerCommandContext, "PlayerCommandContext")

return PlayerCommandContext
