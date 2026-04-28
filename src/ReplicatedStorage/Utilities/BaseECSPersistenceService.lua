--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BasePersistenceService = require(ReplicatedStorage.Utilities.BasePersistenceService)
local Result = require(ReplicatedStorage.Utilities.Result)

local Err = Result.Err
local Ok = Result.Ok

type Result<T> = Result.Result<T>

export type TBaseECSPersistenceService = BasePersistenceService.TBasePersistenceService & {
	World: any,
	Components: any,
}

--[=[
	@class BaseECSPersistenceService
	Adds ECS world/component read helpers to BasePersistenceService.
	@server
]=]
local BaseECSPersistenceService = {}
BaseECSPersistenceService.__index = BaseECSPersistenceService
setmetatable(BaseECSPersistenceService, BasePersistenceService)

function BaseECSPersistenceService.new(
	contextName: string,
	pathSegments: { string },
	errors: BasePersistenceService.TBasePersistenceErrors?
): TBaseECSPersistenceService
	local self = BasePersistenceService.new(contextName, pathSegments, errors)

	self.World = nil
	self.Components = nil

	return setmetatable(self, BaseECSPersistenceService)
end

function BaseECSPersistenceService:Init(registry: any, name: string)
	BasePersistenceService.Init(self, registry, name)

	self.World = registry:Get("World")
	self.Components = registry:Get("Components")

	assert(self.World ~= nil, ("%sPersistenceService: missing World"):format(self._contextName))
	assert(self.Components ~= nil, ("%sPersistenceService: missing Components"):format(self._contextName))
end

function BaseECSPersistenceService:GetComponent(entity: any, component: any): any?
	return self.World:get(entity, component)
end

function BaseECSPersistenceService:RequireComponent(
	entity: any,
	component: any,
	errType: string,
	message: string
): Result<any>
	local componentValue = self:GetComponent(entity, component)
	if componentValue == nil then
		return Err(errType, message)
	end

	return Ok(componentValue)
end

return BaseECSPersistenceService
