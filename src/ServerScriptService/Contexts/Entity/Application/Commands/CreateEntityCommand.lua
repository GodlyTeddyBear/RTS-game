--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local CreateEntityCommand = {}
CreateEntityCommand.__index = CreateEntityCommand
setmetatable(CreateEntityCommand, BaseCommand)

function CreateEntityCommand.new()
	local self = BaseCommand.new("Entity", "CreateEntity")
	return setmetatable(self, CreateEntityCommand)
end
function CreateEntityCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
		_worldRegistry = "EntityWorldRegistryService",
	})
end

function CreateEntityCommand:Execute(archetypeNameOrWorldName: string, payloadOrArchetypeName: any?, maybePayload: any?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "CreateEntity", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local worldName = self._worldRegistry:GetDefaultWorldName()
		local archetypeName = archetypeNameOrWorldName
		local payload = payloadOrArchetypeName
		if type(payloadOrArchetypeName) == "string" then
			worldName = archetypeNameOrWorldName
			archetypeName = payloadOrArchetypeName
			payload = maybePayload
		end

		if self._worldRegistry:IsDefaultWorld(worldName) then
			return self._entityFactory:CreateFromArchetype(archetypeName, payload)
		end

		local factoryResult = self._worldRegistry:GetEntityFactory(worldName)
		if not factoryResult.success then
			return factoryResult
		end
		return factoryResult.value:CreateFromArchetype(archetypeName, payload)
	end, self:_Label())
end

return CreateEntityCommand
