--!strict

--[=[
    @class ProcessPlayerCommand
    Application command that validates and dispatches player NPC commands to the ECS layer.
    @server
]=]

--[[
    ProcessPlayerCommand - Orchestrates player command validation and execution.

    Responsibilities:
    - Validate combat is active and not paused
    - Rate limit commands per player
    - Validate each NPC via NPCCommandPolicy
    - Validate command-specific data
    - Write commands to ECS via CommandWriteService
    - Set NPC to Manual mode on first command

    Pattern: Application layer service — orchestrates Domain + Infrastructure.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommandTypesModule = require(ReplicatedStorage.Contexts.PlayerCommand.Types.CommandTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local Ok, Err, Try, Ensure = Result.Ok, Result.Err, Result.Try, Result.Ensure

local ProcessPlayerCommand = {}
ProcessPlayerCommand.__index = ProcessPlayerCommand

local RATE_LIMIT_INTERVAL = 0.1 -- Minimum seconds between commands per player

export type TProcessPlayerCommand = typeof(setmetatable({} :: {
	NPCCommandPolicy: any,
	AttackTargetPolicy: any,
	CommandWriteService: any,
	CombatLoopService: any,
	NPCEntityFactory: any,
	_LastCommandTime: { [number]: number },
}, ProcessPlayerCommand))

--[=[
    Creates a new `ProcessPlayerCommand` instance.
    @within ProcessPlayerCommand
    @return TProcessPlayerCommand
]=]
function ProcessPlayerCommand.new(): TProcessPlayerCommand
	local self = setmetatable({}, ProcessPlayerCommand)
	self.NPCCommandPolicy = nil :: any
	self.AttackTargetPolicy = nil :: any
	self.CommandWriteService = nil :: any
	self.CombatLoopService = nil :: any
	self.NPCEntityFactory = nil :: any
	self._LastCommandTime = {}
	return self
end

--[=[
    Wires dependencies from the service registry.
    @within ProcessPlayerCommand
    @param registry any -- The context-local service registry
]=]
function ProcessPlayerCommand:Start(registry: any, _name: string)
	self.NPCCommandPolicy = registry:Get("NPCCommandPolicy")
	self.AttackTargetPolicy = registry:Get("AttackTargetPolicy")
	self.CommandWriteService = registry:Get("CommandWriteService")
	self.CombatLoopService = registry:Get("CombatLoopService")
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
end

--[=[
    Validates and executes a player command for one or more NPCs.
    @within ProcessPlayerCommand
    @param userId number -- The player's user ID
    @param commandType string -- One of `"MoveToPosition"`, `"AttackTarget"`, `"HoldPosition"`, or `"AttackNearest"`
    @param npcIds {string} -- List of NPC IDs to command
    @param data {[string]: any} -- Command-specific payload (e.g. `Position`, `TargetNPCId`)
    @return Result<number> -- `Ok(commandedCount)` on success; `Err` if preconditions fail or no NPCs were commanded
]=]
function ProcessPlayerCommand:Execute(
	userId: number,
	commandType: string,
	npcIds: { string },
	data: { [string]: any }
): Result.Result<number>
	self:_AssertCommandPreconditions(userId, commandType)
	self:_ValidateCommandData(userId, commandType, data)

	local writeData = self:_PrepareWriteData(commandType, npcIds, data)
	local commandedCount = self:_CommandNPCs(userId, npcIds, commandType, writeData)

	if commandedCount == 0 then
		return Err("NPCNotFound", Errors.NPC_NOT_FOUND, { userId = userId })
	end

	return Ok(commandedCount)
end

--[=[
    Removes rate-limit tracking state for a user. Call when the player leaves.
    @within ProcessPlayerCommand
    @param userId number -- The player's user ID
]=]
function ProcessPlayerCommand:CleanupUser(userId: number)
	self._LastCommandTime[userId] = nil
end

function ProcessPlayerCommand:_AssertCommandPreconditions(userId: number, commandType: string)
	Ensure(self.CombatLoopService:IsActive(userId), "NoActiveCombat", Errors.NO_ACTIVE_COMBAT)
	local combat = self.CombatLoopService:GetActiveCombat(userId)
	Ensure(not (combat and combat.IsPaused), "CombatPaused", Errors.COMBAT_PAUSED)

	local now = os.clock()
	Ensure(now - (self._LastCommandTime[userId] or 0) >= RATE_LIMIT_INTERVAL, "RateLimited", Errors.RATE_LIMITED)
	self._LastCommandTime[userId] = now

	Ensure(CommandTypesModule.CommandTypes[commandType] ~= nil, "InvalidCommandType", Errors.INVALID_COMMAND_TYPE)
end

function ProcessPlayerCommand:_ValidateCommandData(userId: number, commandType: string, data: { [string]: any })
	if commandType == CommandTypesModule.CommandTypes.MoveToPosition then
		Ensure(typeof(data.Position) == "Vector3", "InvalidPosition", Errors.INVALID_POSITION)
	elseif commandType == CommandTypesModule.CommandTypes.AttackTarget then
		Try(self.AttackTargetPolicy:Check(userId, data))
	end
end

function ProcessPlayerCommand:_PrepareWriteData(
	commandType: string,
	npcIds: { string },
	data: { [string]: any }
): { [string]: any }
	if commandType == CommandTypesModule.CommandTypes.MoveToPosition and #npcIds > 1 then
		local withGroupId = table.clone(data)
		withGroupId.CommandGroupId = HttpService:GenerateGUID(false)
		return withGroupId
	end
	return data
end

function ProcessPlayerCommand:_CommandNPCs(
	userId: number,
	npcIds: { string },
	commandType: string,
	writeData: { [string]: any }
): number
	local commandedCount = 0
	for _, npcId in npcIds do
		local result = self.NPCCommandPolicy:Check(userId, npcId)
		if result.success then
			local entity = (result :: any).value.Entity
			self.CommandWriteService:WriteCommand(entity, commandType, writeData)
			self.CommandWriteService:SetControlMode(entity, "Manual")
			commandedCount += 1
			MentionSuccess("PlayerCommand:ProcessPlayerCommand:CommandWrite",
				`Commanded {npcId}: {commandType}`)
		else
			MentionSuccess("PlayerCommand:ProcessPlayerCommand:Validation",
				`Skipped {npcId}: {(result :: Result.Err).message}`)
		end
	end
	return commandedCount
end

return ProcessPlayerCommand
