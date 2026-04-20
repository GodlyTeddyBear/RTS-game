--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Err, Try = Result.Ok, Result.Err, Result.Try
local MentionSuccess = Result.MentionSuccess

--[=[
	@class AcknowledgeExpedition
	Application command that performs deferred expedition cleanup after the
	player has acknowledged the result screen.
	@server
]=]
local AcknowledgeExpedition = {}
AcknowledgeExpedition.__index = AcknowledgeExpedition

export type TAcknowledgeExpedition = typeof(setmetatable({}, AcknowledgeExpedition))

local _IsTerminalStatus

function AcknowledgeExpedition.new(): TAcknowledgeExpedition
	local self = setmetatable({}, AcknowledgeExpedition)
	return self
end

function AcknowledgeExpedition:Init(registry: any, _name: string)
	self.Registry = registry
	self.QuestSyncService = registry:Get("QuestSyncService")
end

function AcknowledgeExpedition:Start()
	self.DungeonContext = self.Registry:Get("DungeonContext")
end

function AcknowledgeExpedition:Execute(player: Player, userId: number): Result.Result<boolean>
	if not player or userId <= 0 then
		return Err("InvalidInput", Errors.PLAYER_NOT_FOUND, { userId = userId })
	end

	local expedition = self.QuestSyncService:GetActiveExpeditionReadOnly(userId)
	if not expedition then
		return Err("NoActiveExpedition", Errors.NO_ACTIVE_EXPEDITION, { userId = userId })
	end

	if not _IsTerminalStatus(expedition.Status) then
		return Err("ExpeditionNotComplete", Errors.EXPEDITION_NOT_COMPLETE, {
			userId = userId,
			status = expedition.Status,
		})
	end

	if self.DungeonContext then
		Try(self.DungeonContext:DestroyDungeon(player, userId))
	end

	self.QuestSyncService:ClearActiveExpedition(userId)
	MentionSuccess("Quest:AcknowledgeExpedition:Execute", "Acknowledged expedition result and cleared active expedition", {
		userId = userId,
		status = expedition.Status,
	})

	return Ok(true)
end

function _IsTerminalStatus(status: string): boolean
	return status == "Victory" or status == "Defeat" or status == "Fled"
end

return AcknowledgeExpedition
