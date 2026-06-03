--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)

local RegisterEntityFeatureCommand = {}
RegisterEntityFeatureCommand.__index = RegisterEntityFeatureCommand
setmetatable(RegisterEntityFeatureCommand, BaseCommand)

local ASSETS_ROOT = ReplicatedStorage:WaitForChild("Assets")
local ANIMATIONS_FOLDER = ASSETS_ROOT:FindFirstChild("Animations")

local function _FindOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function _ResolveAsset(asset: any): Instance
	local assetKind = if type(asset) == "table" then asset.AssetKind else nil
	if assetKind == "Part" then
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(1.2, 1.2, 1.2)
		part.Color = Color3.fromRGB(255, 199, 93)
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		return part
	end

	local assetDomain = if type(asset) == "table" then asset.AssetDomain else nil
	local assetId = if type(asset) == "table" then asset.AssetId else nil
	assert(type(assetDomain) == "string" and assetDomain ~= "", "Entity generic model asset missing AssetDomain")
	assert(type(assetId) == "string" and assetId ~= "", "Entity generic model asset missing AssetId")

	local domainFolder = ASSETS_ROOT:FindFirstChild(assetDomain)
	assert(domainFolder ~= nil, ("Entity generic model asset missing domain: %s"):format(assetDomain))
	local source = domainFolder:FindFirstChild(assetId)
	assert(source ~= nil, ("Entity generic model asset missing id: %s/%s"):format(assetDomain, assetId))
	return source:Clone()
end

local function _PrepareInstance(instance: Instance, binding: any, snapshot: any)
	local setupProfileId = if type(binding) == "table" then binding.SetupProfileId else nil
	local transform = snapshot.Transform
	if (setupProfileId == "HumanoidActor" or setupProfileId == "StructurePlacement") and instance:IsA("Model") then
		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			humanoid = Instance.new("Humanoid")
			humanoid.Parent = instance
		end
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		local animationsFolderRef = instance:FindFirstChild("AnimationsFolder")
		if animationsFolderRef ~= nil and not animationsFolderRef:IsA("ObjectValue") then
			animationsFolderRef:Destroy()
			animationsFolderRef = nil
		end
		if animationsFolderRef == nil then
			animationsFolderRef = Instance.new("ObjectValue")
			animationsFolderRef.Name = "AnimationsFolder"
			animationsFolderRef.Parent = instance
		end
		if ANIMATIONS_FOLDER ~= nil then
			(animationsFolderRef :: ObjectValue).Value = ANIMATIONS_FOLDER
		end
	end

	if setupProfileId == "StructurePlacement" and instance:IsA("Model") then
		local sourcePlacement = snapshot.FeatureData and snapshot.FeatureData.SourcePlacement or {}
		if sourcePlacement.RotationQuarterTurns ~= 0 then
			ModelPlus.RotateYaw(instance, math.rad((sourcePlacement.RotationQuarterTurns or 0) * 90))
		end
		if typeof(sourcePlacement.WorldPos) == "Vector3" then
			ModelPlus.MoveBottomAligned(instance, sourcePlacement.WorldPos)
		elseif typeof(transform and transform.CFrame) == "CFrame" then
			instance:PivotTo(transform.CFrame)
		end
		EntityCollisionService:ApplyStructureModel(instance)
	elseif instance:IsA("Model") and typeof(transform and transform.CFrame) == "CFrame" then
		instance:PivotTo(transform.CFrame)
		if setupProfileId == "HumanoidActor" then
			EntityCollisionService:ApplyModel(instance)
		end
	elseif instance:IsA("BasePart") and typeof(transform and transform.CFrame) == "CFrame" then
		instance.CFrame = transform.CFrame
	end
end

local function _FormatName(format: string?, snapshot: any): string
	local identity = snapshot.Identity or {}
	local featureName = tostring(snapshot.FeatureName or "Entity")
	local entityId = tostring(identity.EntityId or snapshot.Entity)
	local definitionId = tostring(identity.DefinitionId or featureName)
	if type(format) == "string" and format ~= "" then
		local nextName = string.gsub(format, "{EntityId}", entityId)
		nextName = string.gsub(nextName, "{DefinitionId}", definitionId)
		nextName = string.gsub(nextName, "{FeatureName}", featureName)
		return nextName
	end
	return ("%s_%s_%s"):format(featureName, definitionId, entityId)
end

function RegisterEntityFeatureCommand.new()
	local self = BaseCommand.new("Entity", "RegisterEntityFeature")
	return setmetatable(self, RegisterEntityFeatureCommand)
end

function RegisterEntityFeatureCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_registerFeatureSchemaCommand = "RegisterFeatureSchemaCommand",
		_registerInstanceBindingCommand = "RegisterInstanceBindingCommand",
		_registerSyncContributorCommand = "RegisterSyncContributorCommand",
		_registerReplicationSurfaceCommand = "RegisterReplicationSurfaceCommand",
		_enableRuntimeBindingCommand = "EnableRuntimeBindingCommand",
		_enableRuntimeSyncCommand = "EnableRuntimeSyncCommand",
		_enableRuntimeReplicationCommand = "EnableRuntimeReplicationCommand",
		_schemaRegistry = "EntitySchemaRegistry",
	})
end

function RegisterEntityFeatureCommand:Execute(definition: any): Result.Result<boolean>
	return Result.Catch(function()
		assert(type(definition) == "table", "Invalid entity feature definition")
		local featureName = definition.FeatureName
		assert(type(featureName) == "string" and featureName ~= "", "Invalid entity feature name")

		local schemaResult = self._registerFeatureSchemaCommand:Execute(featureName, definition.Schema)
		if not schemaResult.success and schemaResult.type ~= "DuplicateFeatureSchema" then
			return schemaResult
		end

		local bindingResult = self._registerInstanceBindingCommand:Execute(featureName, self:_BuildGenericBinding(featureName))
		if not bindingResult.success and bindingResult.type ~= "DuplicateInstanceBinding" then
			return bindingResult
		end

		local syncResult = self._registerSyncContributorCommand:Execute(featureName, self:_BuildGenericSyncContributor(featureName))
		if not syncResult.success and syncResult.type ~= "DuplicateSyncContributor" then
			return syncResult
		end

		local replicationResult =
			self._registerReplicationSurfaceCommand:Execute(featureName, self:_BuildGenericReplicationSurface(featureName))
		if not replicationResult.success and replicationResult.type ~= "DuplicateReplicationSurface" then
			return replicationResult
		end

		local bindingEnableResult = self._enableRuntimeBindingCommand:Execute(featureName)
		if not bindingEnableResult.success then
			return bindingEnableResult
		end

		local syncEnableResult = self._enableRuntimeSyncCommand:Execute(featureName)
		if not syncEnableResult.success then
			return syncEnableResult
		end

		local replicationEnableResult = self._enableRuntimeReplicationCommand:Execute(featureName)
		if not replicationEnableResult.success then
			return replicationEnableResult
		end

		return Result.Ok(true)
	end, self:_Label())
end

function RegisterEntityFeatureCommand:_BuildGenericBinding(featureName: string): any
	return {
		FeatureName = featureName,
		ResolveAsset = function(_entityContext: any, snapshot: any): Instance
			return _ResolveAsset(snapshot.ModelAsset)
		end,
		ResolveParentFolder = function(_entityContext: any, snapshot: any): Instance
			local binding = snapshot.ModelBinding or {}
			local parentName = if type(binding.ParentFolder) == "string" and binding.ParentFolder ~= ""
				then binding.ParentFolder
				else snapshot.FeatureName
			return _FindOrCreateFolder(workspace:WaitForChild("EntityRuntime"), parentName)
		end,
		PrepareInstance = function(_entityContext: any, instance: Instance, snapshot: any)
			_PrepareInstance(instance, snapshot.ModelBinding, snapshot)
		end,
		BuildRevealAttributes = function(_entityContext: any, snapshot: any)
			local identity = snapshot.Identity or {}
			local ownership = snapshot.Ownership or {}
			return {
				EntityId = identity.EntityId,
				EntityKind = identity.EntityKind,
				EntityFeature = snapshot.FeatureName,
				Faction = ownership.Faction,
				OwnerKind = ownership.OwnerKind,
				OwnerId = ownership.OwnerId,
			}
		end,
		BuildRevealTags = function(_entityContext: any, snapshot: any)
			local binding = snapshot.ModelBinding or {}
			local revealTag = if type(binding.RevealTag) == "string" and binding.RevealTag ~= ""
				then binding.RevealTag
				else "EntityActor"
			return {
				[revealTag] = true,
			}
		end,
		BuildName = function(_entityContext: any, snapshot: any)
			local binding = snapshot.ModelBinding or {}
			return _FormatName(binding.NameFormat, snapshot)
		end,
	}
end

function RegisterEntityFeatureCommand:_BuildGenericSyncContributor(featureName: string): any
	return {
		FeatureName = featureName,
		BuildHumanoidProperties = function(entityContext: any, entity: number)
			local projection = self:_Read(entityContext, entity, "HumanoidProjection", "Entity")
			if type(projection) ~= "table" or projection.Enabled ~= true then
				return nil
			end
			local health = self:_Read(entityContext, entity, "Health", "Entity")
			local speed = self:_Read(entityContext, entity, "SpeedState", "Movement")
			return {
				MaxHealth = if projection.Health ~= false and type(health) == "table" then health.Max else nil,
				Health = if projection.Health ~= false and type(health) == "table" then health.Current else nil,
				WalkSpeed = if projection.WalkSpeed ~= false and type(speed) == "table" then speed.CurrentSpeed else nil,
			}
		end,
		BuildTransformProjection = function(entityContext: any, entity: number)
			local projection = self:_Read(entityContext, entity, "TransformProjection", "Entity")
			if type(projection) == "table" and projection.Enabled == false then
				return nil
			end
			local transform = self:_Read(entityContext, entity, "Transform", "Entity")
			return if type(transform) == "table" then transform.CFrame else nil
		end,
		PollEntity = function(entityContext: any, entity: number, instance: Instance)
			local poll = self:_Read(entityContext, entity, "TransformPoll", "Entity")
			if type(poll) ~= "table" or poll.Enabled ~= true then
				return
			end
			local cframe = if instance:IsA("Model") then instance:GetPivot() else if instance:IsA("BasePart") then instance.CFrame else nil
			if typeof(cframe) == "CFrame" then
				entityContext:Set(entity, "Transform", { CFrame = cframe }, "Entity")
			end
		end,
	}
end

function RegisterEntityFeatureCommand:_BuildGenericReplicationSurface(featureName: string): any
	return {
		FeatureName = featureName,
		BuildSchema = function(_entityContext: any)
			return self:_BuildReplicatedSchema(featureName)
		end,
	}
end

function RegisterEntityFeatureCommand:_BuildReplicatedSchema(featureName: string): any
	local sharedComponents = {}
	local sharedTags = {}

	local function appendFromSchema(schema: any)
		if schema == nil then
			return
		end
		for _, componentId in pairs(schema.Components or {}) do
			local metadata = self._schemaRegistry:GetComponentMetadataById(componentId)
			if metadata ~= nil and metadata.Replication ~= "ServerOnly" then
				table.insert(sharedComponents, componentId)
			end
		end
		for _, tagId in pairs(schema.Tags or {}) do
			local metadata = self._schemaRegistry:GetComponentMetadataById(tagId)
			if metadata ~= nil and metadata.Replication ~= "ServerOnly" then
				table.insert(sharedTags, tagId)
			end
		end
	end

	appendFromSchema(self._schemaRegistry:GetCoreCompiledSchema())
	appendFromSchema(self._schemaRegistry:GetCompiledSchema(featureName))
	return {
		sharedComponents = sharedComponents,
		sharedTags = sharedTags,
	}
end

function RegisterEntityFeatureCommand:_Read(entityContext: any, entity: number, key: string, featureName: string): any
	local result = entityContext:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return RegisterEntityFeatureCommand
