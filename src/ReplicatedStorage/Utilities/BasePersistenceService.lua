--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Err = Result.Err

type Result<T> = Result.Result<T>

export type TBasePersistenceErrors = {
	ProfileNotLoadedType: string?,
	ProfileNotLoadedMessage: string?,
}

export type TBasePersistenceService = typeof(setmetatable({} :: {
	ProfileManager: any,
	_contextName: string,
	_pathSegments: { string },
	_profileNotLoadedType: string,
	_profileNotLoadedMessage: string,
}, {} :: any))

--[=[
	@class BasePersistenceService
	Shared ProfileManager and profile-path helper for context persistence services.
	@server
]=]
local BasePersistenceService = {}
BasePersistenceService.__index = BasePersistenceService

function BasePersistenceService.new(
	contextName: string,
	pathSegments: { string },
	errors: TBasePersistenceErrors?
): TBasePersistenceService
	local self = setmetatable({}, BasePersistenceService)

	self.ProfileManager = nil
	self._contextName = contextName
	self._pathSegments = table.clone(pathSegments)
	self._profileNotLoadedType = errors and errors.ProfileNotLoadedType or "ProfileNotLoaded"
	self._profileNotLoadedMessage = errors and errors.ProfileNotLoadedMessage
		or ("[%s:Persistence] Profile not loaded"):format(contextName)

	return self
end

function BasePersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
	assert(self.ProfileManager ~= nil, ("%sPersistenceService: missing ProfileManager"):format(self._contextName))
end

function BasePersistenceService:GetProfileData(player: Player): Result<any>
	local profileData = self.ProfileManager:GetData(player)
	if profileData == nil then
		return Err(self._profileNotLoadedType, self._profileNotLoadedMessage)
	end

	return Ok(profileData)
end

function BasePersistenceService:LoadPathData(player: Player): Result<any?>
	local profileDataResult = self:GetProfileData(player)
	if not profileDataResult.success then
		return profileDataResult
	end

	local current = profileDataResult.value
	for _, segment in self._pathSegments do
		current = current[segment]
		if current == nil then
			return Ok(nil)
		end
	end

	return Ok(self:DeepCopy(current))
end

function BasePersistenceService:EnsurePath(player: Player): Result<any>
	local profileDataResult = self:GetProfileData(player)
	if not profileDataResult.success then
		return profileDataResult
	end

	local current = profileDataResult.value
	for _, segment in self._pathSegments do
		local nextValue = current[segment]
		if nextValue == nil then
			nextValue = {}
			current[segment] = nextValue
		end
		current = nextValue
	end

	return Ok(current)
end

function BasePersistenceService:SetPathValue(player: Player, key: any, value: any): Result<boolean>
	local pathResult = self:EnsurePath(player)
	if not pathResult.success then
		return pathResult
	end

	pathResult.value[key] = value
	return Ok(true)
end

function BasePersistenceService:DeletePathValue(player: Player, key: any): Result<boolean>
	local profileDataResult = self:GetProfileData(player)
	if not profileDataResult.success then
		return profileDataResult
	end

	local current = profileDataResult.value
	for _, segment in self._pathSegments do
		current = current[segment]
		if current == nil then
			return Ok(true)
		end
	end

	current[key] = nil
	return Ok(true)
end

function BasePersistenceService:SaveAll(items: { any }, saveOne: (any) -> Result<boolean>): Result<boolean>
	for _, item in items do
		local result = saveOne(item)
		if not result.success then
			return result
		end
	end

	return Ok(true)
end

function BasePersistenceService:DeepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, item in value do
		clone[key] = self:DeepCopy(item)
	end

	return clone
end

return BasePersistenceService
