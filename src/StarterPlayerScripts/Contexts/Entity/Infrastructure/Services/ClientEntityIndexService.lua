--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local ECS = require(ReplicatedStorage.Utilities.ECS)

type TClientEntityRecord = {
	Entity: number,
	FeatureName: string,
	ArchetypeName: string?,
	Identity: any?,
	Ownership: any?,
	Transform: any?,
	Health: any?,
	Lifetime: any?,
	Target: any?,
	ModelRef: any?,
	Tags: { [string]: boolean },
	Components: { [string]: any },
}

local DEBUG_PREFIX = "[AnimationPipeline]"

local SHARED_FIELD_KEYS = table.freeze({
	Identity = "Identity",
	Ownership = "Ownership",
	Transform = "Transform",
	Health = "Health",
	Lifetime = "Lifetime",
	Target = "Target",
	ModelRef = "ModelRef",
})

local function _DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = _DeepClone(nestedValue)
	end
	return clone
end

local function _CloneFrozenArray(values: { any }): { any }
	local cloned = table.clone(values)
	return table.freeze(cloned)
end

local function _BuildIndexKey(left: string, right: string): string
	return left .. "\0" .. right
end

local function _CountMap(source: { [any]: any }): number
	local count = 0
	for _ in pairs(source) do
		count += 1
	end
	return count
end

local function _HasAnimationTag(record: TClientEntityRecord): boolean
	return record.Tags["Animation.EnabledTag"] == true or record.Tags.EnabledTag == true
end

local function _HasAnimationProfile(record: TClientEntityRecord): boolean
	return type(record.Components["Animation.Profile"]) == "table" or type(record.Components.Profile) == "table"
end

local function _FormatScalarFields(source: any): string
	if type(source) ~= "table" then
		return "{}"
	end

	local fields = {}
	for key, value in pairs(source) do
		local valueType = type(value)
		if valueType == "string" or valueType == "number" or valueType == "boolean" then
			table.insert(fields, ("%s=%s"):format(tostring(key), tostring(value)))
		end
	end
	table.sort(fields)
	return "{" .. table.concat(fields, ", ") .. "}"
end

local ClientEntityIndexService = {}
ClientEntityIndexService.__index = ClientEntityIndexService

function ClientEntityIndexService.new(replicationClient: any)
	local self = setmetatable({}, ClientEntityIndexService)
	self._replicationClient = replicationClient
	self._stateChangedConnection = nil
	self._discoveryIndex = ECS.DiscoveryIndexService.new({
		PollIntervalSeconds = 0.25,
	})
	self._recordsByEntity = {}
	self._recordsByFeature = {}
	self._recordsByArchetype = {}
	self._recordsByTag = {}
	self._identityByFeatureAndKey = {}
	self._recordsByIdentityField = {}
	self._featureSignals = {}
	self._archetypeSignals = {}
	self._instanceByEntity = {}
	self._entityByInstance = {}
	self._debugLastIndexSummary = nil
	self._debugInstanceLookupStates = {}
	return self
end

function ClientEntityIndexService:Start()
	self._discoveryIndex:Start()
	self._stateChangedConnection = self._replicationClient:ObserveStateChanged(function()
		self:_RebuildIndexes()
	end)

	if self._replicationClient:HasCompletedBootstrap() then
		self:_RebuildIndexes()
	end
end

function ClientEntityIndexService:GetByFeature(featureName: string): { TClientEntityRecord }
	return _CloneFrozenArray(self._recordsByFeature[featureName] or {})
end

function ClientEntityIndexService:GetByArchetype(archetypeName: string): { TClientEntityRecord }
	return _CloneFrozenArray(self._recordsByArchetype[archetypeName] or {})
end

function ClientEntityIndexService:GetByTag(tagName: string): { TClientEntityRecord }
	return _CloneFrozenArray(self._recordsByTag[tagName] or {})
end

function ClientEntityIndexService:GetByIdentity(featureName: string, identityKey: string): TClientEntityRecord?
	return self._identityByFeatureAndKey[_BuildIndexKey(featureName, identityKey)]
end

function ClientEntityIndexService:GetEntity(entityId: number): TClientEntityRecord?
	return self._recordsByEntity[entityId]
end

function ClientEntityIndexService:ObserveByFeature(featureName: string, callback: (any) -> ())
	local signal = self:_GetFeatureSignal(featureName)
	return signal:Connect(callback)
end

function ClientEntityIndexService:ObserveByArchetype(archetypeName: string, callback: (any) -> ())
	local signal = self:_GetArchetypeSignal(archetypeName)
	return signal:Connect(callback)
end

function ClientEntityIndexService:FindInstanceByEntity(entityId: number): Instance?
	local record = self._recordsByEntity[entityId]
	if record == nil then
		return nil
	end

	local cachedInstance = self._instanceByEntity[entityId]
	if cachedInstance ~= nil and cachedInstance.Parent ~= nil then
		return cachedInstance
	end

	local resolvedInstance = self:_FindInstanceForRecord(record)
	if resolvedInstance ~= nil then
		self._instanceByEntity[entityId] = resolvedInstance
		self._entityByInstance[resolvedInstance] = entityId
		self:_LogInstanceLookup(entityId, "resolved", record, resolvedInstance)
	else
		self:_LogInstanceLookup(entityId, "missing", record, nil)
	end

	return resolvedInstance
end

function ClientEntityIndexService:FindRecordByInstance(instance: Instance): TClientEntityRecord?
	local cachedEntity = self._entityByInstance[instance]
	if cachedEntity ~= nil then
		return self._recordsByEntity[cachedEntity]
	end

	for attributeName, attributeValue in instance:GetAttributes() do
		if type(attributeValue) == "string" or type(attributeValue) == "number" then
			local record = self._recordsByIdentityField[_BuildIndexKey(attributeName, tostring(attributeValue))]
			if record ~= nil then
				self._entityByInstance[instance] = record.Entity
				self._instanceByEntity[record.Entity] = instance
				return record
			end
		end
	end

	return nil
end

function ClientEntityIndexService:Destroy()
	if self._stateChangedConnection ~= nil then
		self._stateChangedConnection:Disconnect()
		self._stateChangedConnection = nil
	end

	if self._discoveryIndex ~= nil then
		self._discoveryIndex:Destroy()
	end

	for _, signal in pairs(self._featureSignals) do
		signal:DisconnectAll()
	end
	for _, signal in pairs(self._archetypeSignals) do
		signal:DisconnectAll()
	end

	table.clear(self._featureSignals)
	table.clear(self._archetypeSignals)
	table.clear(self._recordsByEntity)
	table.clear(self._recordsByFeature)
	table.clear(self._recordsByArchetype)
	table.clear(self._recordsByTag)
	table.clear(self._identityByFeatureAndKey)
	table.clear(self._recordsByIdentityField)
	table.clear(self._instanceByEntity)
	table.clear(self._entityByInstance)
	table.clear(self._debugInstanceLookupStates)
end

function ClientEntityIndexService:_GetFeatureSignal(featureName: string)
	local existing = self._featureSignals[featureName]
	if existing ~= nil then
		return existing
	end

	local signal = GoodSignal.new()
	self._featureSignals[featureName] = signal
	return signal
end

function ClientEntityIndexService:_GetArchetypeSignal(archetypeName: string)
	local existing = self._archetypeSignals[archetypeName]
	if existing ~= nil then
		return existing
	end

	local signal = GoodSignal.new()
	self._archetypeSignals[archetypeName] = signal
	return signal
end

function ClientEntityIndexService:_RebuildIndexes()
	if not self._replicationClient:HasCompletedBootstrap() then
		return
	end

	local world = self._replicationClient:GetWorldOrThrow()
	local components = self._replicationClient:GetComponentsOrThrow()
	local featureNameComponent = components.ByECSName["Entity.FeatureName"]
	local archetypeNameComponent = components.ByECSName["Entity.ArchetypeName"]
	if featureNameComponent == nil or archetypeNameComponent == nil then
		return
	end

	local previousRecordsByEntity = self._recordsByEntity
	local previousRecordsByFeature = self._recordsByFeature
	local previousRecordsByArchetype = self._recordsByArchetype

	local nextRecordsByEntity = {}
	local nextRecordsByFeature = {}
	local nextRecordsByArchetype = {}
	local nextRecordsByTag = {}
	local nextIdentityByFeatureAndKey = {}
	local nextRecordsByIdentityField = {}

	table.clear(self._instanceByEntity)
	table.clear(self._entityByInstance)

	for clientEntity, featureNameValue, archetypeNameValue in world:query(featureNameComponent, archetypeNameComponent):iter() do
		if type(featureNameValue) ~= "string" or featureNameValue == "" then
			continue
		end

		local serverEntity = self._replicationClient:GetServerEntity(clientEntity)
		if type(serverEntity) ~= "number" then
			continue
		end

		local record = self:_BuildRecord(
			world,
			components,
			clientEntity,
			serverEntity,
			featureNameValue,
			if type(archetypeNameValue) == "string" then archetypeNameValue else nil
		)
		nextRecordsByEntity[serverEntity] = record

		local featureRecords = nextRecordsByFeature[featureNameValue]
		if featureRecords == nil then
			featureRecords = {}
			nextRecordsByFeature[featureNameValue] = featureRecords
		end
		table.insert(featureRecords, record)

		if record.ArchetypeName ~= nil then
			local archetypeRecords = nextRecordsByArchetype[record.ArchetypeName]
			if archetypeRecords == nil then
				archetypeRecords = {}
				nextRecordsByArchetype[record.ArchetypeName] = archetypeRecords
			end
			table.insert(archetypeRecords, record)
		end

		for tagName in pairs(record.Tags) do
			local taggedRecords = nextRecordsByTag[tagName]
			if taggedRecords == nil then
				taggedRecords = {}
				nextRecordsByTag[tagName] = taggedRecords
			end
			table.insert(taggedRecords, record)
		end

		self:_IndexIdentity(nextIdentityByFeatureAndKey, nextRecordsByIdentityField, record)
	end

	self._recordsByEntity = nextRecordsByEntity
	self._recordsByFeature = nextRecordsByFeature
	self._recordsByArchetype = nextRecordsByArchetype
	self._recordsByTag = nextRecordsByTag
	self._identityByFeatureAndKey = nextIdentityByFeatureAndKey
	self._recordsByIdentityField = nextRecordsByIdentityField
	self:_LogIndexSummary()

	self:_NotifyObservers(previousRecordsByFeature, nextRecordsByFeature, previousRecordsByArchetype, nextRecordsByArchetype, previousRecordsByEntity)
end

function ClientEntityIndexService:_LogIndexSummary()
	local totalRecords = _CountMap(self._recordsByEntity)
	local animationTagged = 0
	local animationProfiled = 0
	for _, record in pairs(self._recordsByEntity) do
		if _HasAnimationTag(record) then
			animationTagged += 1
		end
		if _HasAnimationProfile(record) then
			animationProfiled += 1
		end
	end

	local summary = ("%d/%d/%d"):format(totalRecords, animationTagged, animationProfiled)
	if self._debugLastIndexSummary == summary then
		return
	end
	self._debugLastIndexSummary = summary
	warn(
		DEBUG_PREFIX,
		"entity index rebuilt",
		"records",
		totalRecords,
		"animationTagged",
		animationTagged,
		"animationProfiled",
		animationProfiled
	)
end

function ClientEntityIndexService:_LogInstanceLookup(entityId: number, state: string, record: TClientEntityRecord, instance: Instance?)
	local key = tostring(entityId) .. ":" .. state
	if self._debugInstanceLookupStates[key] == true then
		return
	end
	self._debugInstanceLookupStates[key] = true

	if state == "resolved" and instance ~= nil then
		warn(DEBUG_PREFIX, "instance resolved", "entity", entityId, "instance", instance:GetFullName())
		return
	end

	warn(
		DEBUG_PREFIX,
		"instance missing",
		"entity",
		entityId,
		"identity",
		_FormatScalarFields(record.Identity),
		"modelRef",
		_FormatScalarFields(record.ModelRef)
	)
end

function ClientEntityIndexService:_BuildRecord(
	world: any,
	components: any,
	clientEntity: any,
	serverEntity: number,
	featureName: string,
	archetypeName: string?
): TClientEntityRecord
	local record = {
		Entity = serverEntity,
		FeatureName = featureName,
		ArchetypeName = archetypeName,
		Identity = nil,
		Ownership = nil,
		Transform = nil,
		Health = nil,
		Lifetime = nil,
		Target = nil,
		ModelRef = nil,
		Tags = {},
		Components = {},
	}

	for _, ecsName in ipairs(components.SharedComponentNames) do
		local componentId = components.ByECSName[ecsName]
		local metadata = components.MetadataByECSName[ecsName]
		if componentId == nil or metadata == nil then
			continue
		end
		local value = world:get(clientEntity, componentId)
		if value == nil then
			continue
		end

		local clonedValue = _DeepClone(value)
		local componentKey = if type(metadata.Key) == "string" and metadata.Key ~= "" then metadata.Key else metadata.ECSName
		record.Components[metadata.ECSName] = clonedValue
		if record.Components[componentKey] == nil then
			record.Components[componentKey] = clonedValue
		end

		local sharedFieldKey = SHARED_FIELD_KEYS[componentKey]
		if sharedFieldKey ~= nil then
			(record :: any)[sharedFieldKey] = clonedValue
		end
	end

	for _, ecsName in ipairs(components.SharedTagNames) do
		local tagId = components.ByECSName[ecsName]
		local metadata = components.MetadataByECSName[ecsName]
		if tagId == nil or metadata == nil then
			continue
		end
		if not world:has(clientEntity, tagId) then
			continue
		end

		record.Tags[ecsName] = true
		if type(metadata.Key) == "string" and metadata.Key ~= "" then
			record.Tags[metadata.Key] = true
		end
	end

	return table.freeze(record) :: TClientEntityRecord
end

function ClientEntityIndexService:_IndexIdentity(
	identityByFeatureAndKey: { [string]: TClientEntityRecord },
	recordsByIdentityField: { [string]: TClientEntityRecord },
	record: TClientEntityRecord
)
	if type(record.Identity) ~= "table" then
		return
	end

	for fieldName, fieldValue in pairs(record.Identity) do
		local valueType = type(fieldValue)
		if valueType == "string" or valueType == "number" then
			local scalarValue = tostring(fieldValue)
			identityByFeatureAndKey[_BuildIndexKey(record.FeatureName, scalarValue)] = record
			recordsByIdentityField[_BuildIndexKey(tostring(fieldName), scalarValue)] = record
		end
	end
end

function ClientEntityIndexService:_NotifyObservers(
	previousRecordsByFeature: { [string]: { TClientEntityRecord } },
	nextRecordsByFeature: { [string]: { TClientEntityRecord } },
	previousRecordsByArchetype: { [string]: { TClientEntityRecord } },
	nextRecordsByArchetype: { [string]: { TClientEntityRecord } },
	previousRecordsByEntity: { [number]: TClientEntityRecord }
)
	local processedFeatures = {}
	for featureName, signal in pairs(self._featureSignals) do
		processedFeatures[featureName] = true
		self:_FireSignalForRecordGroup(
			signal,
			previousRecordsByFeature[featureName] or {},
			nextRecordsByFeature[featureName] or {},
			previousRecordsByEntity
		)
	end
	for featureName in pairs(nextRecordsByFeature) do
		if processedFeatures[featureName] then
			continue
		end

		local signal = self._featureSignals[featureName]
		if signal ~= nil then
			self:_FireSignalForRecordGroup(signal, previousRecordsByFeature[featureName] or {}, nextRecordsByFeature[featureName], previousRecordsByEntity)
		end
	end

	local processedArchetypes = {}
	for archetypeName, signal in pairs(self._archetypeSignals) do
		processedArchetypes[archetypeName] = true
		self:_FireSignalForRecordGroup(
			signal,
			previousRecordsByArchetype[archetypeName] or {},
			nextRecordsByArchetype[archetypeName] or {},
			previousRecordsByEntity
		)
	end
	for archetypeName in pairs(nextRecordsByArchetype) do
		if processedArchetypes[archetypeName] then
			continue
		end

		local signal = self._archetypeSignals[archetypeName]
		if signal ~= nil then
			self:_FireSignalForRecordGroup(
				signal,
				previousRecordsByArchetype[archetypeName] or {},
				nextRecordsByArchetype[archetypeName],
				previousRecordsByEntity
			)
		end
	end
end

function ClientEntityIndexService:_FireSignalForRecordGroup(
	signal: any,
	previousRecords: { TClientEntityRecord },
	nextRecords: { TClientEntityRecord },
	previousRecordsByEntity: { [number]: TClientEntityRecord }
)
	local nextEntityIds = {}
	for _, record in ipairs(nextRecords) do
		nextEntityIds[record.Entity] = true
	end

	for _, record in ipairs(previousRecords) do
		if nextEntityIds[record.Entity] ~= true then
			signal:Fire(record.Entity)
		end
	end

	for _, record in ipairs(nextRecords) do
		local previousRecord = previousRecordsByEntity[record.Entity]
		if previousRecord == nil or previousRecord ~= record then
			signal:Fire(record)
		end
	end
end

function ClientEntityIndexService:_FindInstanceForRecord(record: TClientEntityRecord): Instance?
	for fieldName, fieldValue in pairs(record.Identity or {}) do
		local valueType = type(fieldValue)
		if valueType == "string" or valueType == "number" then
			local instance = self._discoveryIndex:FindFirstByAttribute(tostring(fieldName), fieldValue)
			if instance ~= nil then
				return instance
			end
		end
	end

	for fieldName, fieldValue in pairs(record.ModelRef or {}) do
		local valueType = type(fieldValue)
		if valueType == "string" or valueType == "number" then
			local instance = self._discoveryIndex:FindFirstByAttribute(tostring(fieldName), fieldValue)
			if instance ~= nil then
				return instance
			end
		end
	end

	return nil
end

return ClientEntityIndexService
