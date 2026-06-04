--!strict

--[=[
    @class PrepareRunBaseCommand
    Prepares the base runtime entity and sync state before a run starts.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local BaseConfig = require(ReplicatedStorage.Contexts.Base.Config.BaseConfig)
local ECS = require(ReplicatedStorage.Utilities.ECS)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

local function _ApplyBaseReveal(instance: Instance)
	local _entityId, revealState = ECS.RevealBuilder.Build({
		EntityType = BaseConfig.REVEAL_ENTITY_TYPE,
		SourceId = BaseConfig.BASE_ID,
		ScopeId = BaseConfig.REVEAL_SCOPE_ID,
		Namespace = BaseConfig.REVEAL_NAMESPACE,
	})

	for attributeName, value in pairs(revealState.Attributes or {}) do
		instance:SetAttribute(attributeName, value)
	end
	instance:SetAttribute("BaseId", BaseConfig.BASE_ID)

	for tagName, enabled in pairs(revealState.Tags or {}) do
		if enabled == true then
			CollectionService:AddTag(instance, tagName)
		end
	end
end

local PrepareRunBaseCommand = {}
PrepareRunBaseCommand.__index = PrepareRunBaseCommand
setmetatable(PrepareRunBaseCommand, BaseCommand)

--[=[
    Create a new prepare-run command.
    @within PrepareRunBaseCommand
    @return PrepareRunBaseCommand -- Command instance.
]=]
function PrepareRunBaseCommand.new()
	local self = BaseCommand.new("Base", "PrepareRunBaseCommand")
	return setmetatable(self, PrepareRunBaseCommand)
end

--[=[
    Bind the base entity factory and sync service dependencies.
    @within PrepareRunBaseCommand
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function PrepareRunBaseCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityContext = "EntityContext",
		_baseEntityReadService = "BaseEntityReadService",
		_syncService = "BaseSyncService",
	})
end

--[=[
    Bind the map context dependency before execution begins.
    @within PrepareRunBaseCommand
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function PrepareRunBaseCommand:Start(registry: any, _name: string)
	self:_RequireDependency(registry, "_mapContext", "MapContext")
end

--[=[
    Create or reset the base for the active map and hydrate all players.
    @within PrepareRunBaseCommand
    @return Result.Result<boolean> -- Whether the prepare step succeeded.
]=]
function PrepareRunBaseCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(self._mapContext ~= nil, "MissingDependency", Errors.MISSING_MAP_CONTEXT)

		local baseInstance = Try(self._mapContext:GetBaseInstance())
		Ensure(baseInstance ~= nil, "BaseInstanceNotFound", Errors.BASE_INSTANCE_NOT_FOUND)

		local baseAnchor = Try(self._mapContext:GetBaseAnchor())
		Ensure(baseAnchor ~= nil, "BaseAnchorNotFound", Errors.BASE_ANCHOR_NOT_FOUND)
		_ApplyBaseReveal(baseInstance)

		local existingEntity = self._baseEntityReadService:GetActiveBaseEntity()
		if existingEntity ~= nil then
			Try(self._entityContext:DestroyEntity(existingEntity))
		end

		local createResult = self._entityContext:CreateEntity("Base.Actor", {
			Identity = {
				EntityId = BaseConfig.BASE_ID,
				EntityKind = "Base",
				DefinitionId = "PrimaryBase",
			},
			Health = {
				Current = BaseConfig.MAX_HP,
				Max = BaseConfig.MAX_HP,
			},
			Transform = {
				CFrame = baseAnchor.CFrame,
			},
			ModelRef = {
				Model = baseInstance,
			},
			ModelAsset = {
				AssetDomain = "Base",
				AssetId = BaseConfig.BASE_ID,
				AssetKind = "Existing",
			},
			ModelBinding = {
				ParentFolder = "Base",
				SetupProfileId = "ExistingMapInstance",
				RevealTag = "Base",
				NameFormat = "Base_{EntityId}",
			},
			HumanoidProjection = {
				Enabled = false,
				Health = false,
				WalkSpeed = false,
			},
			TransformProjection = {
				Enabled = false,
			},
			TransformPoll = {
				Enabled = false,
			},
			CleanupOutcomes = {
				OutcomeIds = {},
			},
			HealthDepletedOutcome = {
				OutcomeId = "RunFailure",
				Data = {
					Reason = "BaseDestroyed",
					EmitEvent = "BaseDestroyed",
				},
			},
			State = {
				BaseId = BaseConfig.BASE_ID,
			},
			AnchorRef = {
				Anchor = baseAnchor,
			},
			MapInstanceRef = {
				Instance = baseInstance,
			},
		})
		Try(createResult)
		self._syncService:SyncBaseState()
		self._syncService:HydrateAllPlayers()

		return Ok(true)
	end, self:_Label())
end

return PrepareRunBaseCommand
