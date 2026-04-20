--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestTypes = require(ReplicatedStorage.Contexts.Quest.Types.QuestTypes)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Err = Result.Ok, Result.Err

type TQuestState = QuestTypes.TQuestState
type TResult<T> = Result.Result<T>

--[[
	QuestPersistenceService

	Thin bridge between the Quest context and ProfileManager for ProfileStore persistence.
]]

local QuestPersistenceService = {}
QuestPersistenceService.__index = QuestPersistenceService

export type TQuestPersistenceService = typeof(setmetatable({} :: { ProfileManager: any }, QuestPersistenceService))

function QuestPersistenceService.new(): TQuestPersistenceService
	local self = setmetatable({}, QuestPersistenceService)
	return self
end

function QuestPersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
end

--- Deep copy utility to prevent external mutation
local function _DeepCopy(original: any): any
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for k, v in original do
		copy[k] = _DeepCopy(v)
	end
	return copy
end

--- Load quest state from a player's profile
function QuestPersistenceService:LoadQuestState(player: Player): TQuestState?
	local data = self.ProfileManager:GetData(player)
	if not data or not data.Quest then
		return nil
	end
	return _DeepCopy(data.Quest) :: TQuestState
end

--- Save quest state to a player's profile
function QuestPersistenceService:SaveQuestState(player: Player, questState: TQuestState): TResult<boolean>
	local data = self.ProfileManager:GetData(player)
	if not data then
		return Err("PersistenceFailed", "No profile data", { userId = player.UserId })
	end
	data.Quest = _DeepCopy(questState)
	return Ok(true)
end

return QuestPersistenceService
