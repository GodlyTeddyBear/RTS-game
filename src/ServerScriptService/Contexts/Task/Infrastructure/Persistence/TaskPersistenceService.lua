--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local TaskTypes = require(ReplicatedStorage.Contexts.Task.Types.TaskTypes)

local Ok, Try, fromNilable = Result.Ok, Result.Try, Result.fromNilable

type TTaskState = TaskTypes.TTaskState

local DEFAULT_STATE: TTaskState = {
	Tasks = {},
}

local TaskPersistenceService = {}
TaskPersistenceService.__index = TaskPersistenceService

local function _DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nested in pairs(value) do
		clone[key] = _DeepClone(nested)
	end
	return clone
end

function TaskPersistenceService.new()
	return setmetatable({}, TaskPersistenceService)
end

function TaskPersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
end

function TaskPersistenceService:LoadTaskState(player: Player): TTaskState
	local profileData = self.ProfileManager:GetData(player)
	if not profileData then
		return _DeepClone(DEFAULT_STATE)
	end

	if not profileData.Task then
		profileData.Task = _DeepClone(DEFAULT_STATE)
	end

	profileData.Task.Tasks = profileData.Task.Tasks or {}
	return _DeepClone(profileData.Task)
end

function TaskPersistenceService:SaveTaskState(player: Player, state: TTaskState): Result.Result<boolean>
	local profileData = Try(fromNilable(
		self.ProfileManager:GetData(player),
		"PersistenceFailed",
		"No profile data",
		{ userId = player.UserId }
	))

	profileData.Task = _DeepClone(state)
	return Ok(true)
end

return TaskPersistenceService
