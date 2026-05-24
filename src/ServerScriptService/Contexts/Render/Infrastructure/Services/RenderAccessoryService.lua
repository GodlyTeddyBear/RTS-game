--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CollectionService = game:GetService("CollectionService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderAccessoryTransportSchema = require(ReplicatedStorage.Contexts.Render.RenderAccessoryTransportSchema)
local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)
local RenderVisualReplacementConfig =
	require(ReplicatedStorage.Contexts.Render.Config.RenderVisualReplacementConfig)
local RenderTypes = require(ReplicatedStorage.Contexts.Render.Types.RenderTypes)

type TRenderAccessoryEntry = RenderTypes.TRenderAccessoryEntry
type TRenderAccessoryBootstrapChunk = RenderTypes.TRenderAccessoryBootstrapChunk
type TRenderAccessoryDelta = RenderTypes.TRenderAccessoryDelta
type TRenderId = RenderTypes.TRenderId

local RenderAccessoryService = {}
RenderAccessoryService.__index = RenderAccessoryService

local function _GetRenderIdFromInstance(instance: Instance): string?
	local prefix = RenderConfig.RegistryTagPrefix
	for _, tag in ipairs(CollectionService:GetTags(instance)) do
		if string.sub(tag, 1, #prefix) == prefix then
			local renderId = string.sub(tag, #prefix + 1)
			if renderId ~= "" then
				return renderId
			end
		end
	end

	return nil
end

function RenderAccessoryService.new()
	local self = setmetatable({}, RenderAccessoryService)
	self._janitor = Janitor.new()
	self._clientSignals = nil
	self._renderRegistryService = nil
	self._entriesByAccessoryId = {} :: { [string]: TRenderAccessoryEntry }
	self._accessoryIdByInstance = {} :: { [Accessory]: string }
	self._pendingAccessories = {} :: { [Accessory]: true }
	self._hydratedPlayers = {} :: { [Player]: true }
	return self
end

function RenderAccessoryService:Init(registry: any, _name: string)
	self._clientSignals = registry:Get("ClientSignals")
	self._renderRegistryService = registry:Get("RenderRegistryService")
	assert(self._clientSignals ~= nil, "RenderAccessoryService: missing ClientSignals")
	assert(self._renderRegistryService ~= nil, "RenderAccessoryService: missing RenderRegistryService")
end

function RenderAccessoryService:Start()
	self:_TrackWorkspaceAccessories()
	self:_TrackRegistryResolution()
	self:_TrackPlayerLifecycle()
	self:_ScanWorkspaceAccessories()
end

function RenderAccessoryService:Destroy()
	self._clientSignals = nil
	self._renderRegistryService = nil
	table.clear(self._entriesByAccessoryId)
	table.clear(self._accessoryIdByInstance)
	table.clear(self._pendingAccessories)
	table.clear(self._hydratedPlayers)
	self._janitor:Destroy()
end

function RenderAccessoryService:HydratePlayer(player: Player): boolean
	if not self:_IsPlayerValid(player) then
		return false
	end

	local entries = self:_BuildSortedEntries()
	local chunkSize = RenderConfig.RegistryBootstrapChunkSize
	local chunkCount = math.max(1, math.ceil(#entries / chunkSize))

	for chunkIndex = 1, chunkCount do
		local startIndex = ((chunkIndex - 1) * chunkSize) + 1
		local endIndex = math.min(startIndex + chunkSize - 1, #entries)
		local payload = self:_BuildBootstrapChunk(entries, chunkIndex, chunkCount, startIndex, endIndex)
		local encodedPayload, serializeError = RenderAccessoryTransportSchema.SerializeBootstrapChunk(payload)
		if encodedPayload == nil then
			warn(`RenderAccessoryService: failed to serialize bootstrap chunk {chunkIndex}/{chunkCount}: {serializeError}`)
			return false
		end

		self._clientSignals.RenderAccessoryBootstrapChunk:Fire(player, encodedPayload)
	end

	self._hydratedPlayers[player] = true
	return true
end

function RenderAccessoryService:_TrackWorkspaceAccessories()
	self._janitor:Add(Workspace.DescendantAdded:Connect(function(instance: Instance)
		self:_TrackAccessoryInstance(instance)
	end), "Disconnect")

	self._janitor:Add(Workspace.DescendantRemoving:Connect(function(instance: Instance)
		self:_HandleAccessoryRemoving(instance)
	end), "Disconnect")
end

function RenderAccessoryService:_TrackRegistryResolution()
	self._janitor:Add(self._renderRegistryService:ObserveEntryChanged(function(_id: TRenderId)
		self:_RetryPendingAccessories()
	end), "Disconnect")
end

function RenderAccessoryService:_TrackPlayerLifecycle()
	self._janitor:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self._hydratedPlayers[player] = nil
	end), "Disconnect")
end

function RenderAccessoryService:_ScanWorkspaceAccessories()
	for _, instance in ipairs(Workspace:GetDescendants()) do
		self:_TrackAccessoryInstance(instance)
	end
end

function RenderAccessoryService:_TrackAccessoryInstance(instance: Instance)
	if not instance:IsA("Accessory") then
		return
	end

	local accessory = instance :: Accessory
	if self._accessoryIdByInstance[accessory] ~= nil then
		return
	end

	if not self:_TryRegisterAccessory(accessory) then
		self._pendingAccessories[accessory] = true
	end
end

function RenderAccessoryService:_RetryPendingAccessories()
	local pendingAccessories = {}
	for accessory in self._pendingAccessories do
		table.insert(pendingAccessories, accessory)
	end

	for _, accessory in ipairs(pendingAccessories) do
		if accessory.Parent == nil then
			self._pendingAccessories[accessory] = nil
		elseif self:_TryRegisterAccessory(accessory) then
			self._pendingAccessories[accessory] = nil
		end
	end
end

function RenderAccessoryService:_TryRegisterAccessory(accessory: Accessory): boolean
	if accessory.Parent == nil or not accessory:IsDescendantOf(Workspace) then
		return false
	end

	local visualId = RenderVisualReplacementConfig.GetVisualReplacementId(accessory)
	if visualId == nil then
		return false
	end

	local parentRenderId = self:_ResolveParentRenderId(accessory)
	if parentRenderId == nil then
		return false
	end

	local existingAccessoryId = self._accessoryIdByInstance[accessory]
	if existingAccessoryId ~= nil then
		local existingEntry = self._entriesByAccessoryId[existingAccessoryId]
		if existingEntry ~= nil
			and existingEntry.ParentRenderId == parentRenderId
			and existingEntry.VisualId == visualId
			and existingEntry.AccessoryName == accessory.Name then
			return true
		end

		self:RemoveAccessoryEntries({ existingAccessoryId })
	end

	local accessoryId = HttpService:GenerateGUID(false)
	local entry: TRenderAccessoryEntry = {
		AccessoryId = accessoryId,
		AccessoryName = accessory.Name,
		ParentRenderId = parentRenderId,
		VisualId = visualId,
	}

	self._entriesByAccessoryId[accessoryId] = entry
	self._accessoryIdByInstance[accessory] = accessoryId
	self:_BroadcastAddDeltaForEntries({ entry })
	return true
end

function RenderAccessoryService:_HandleAccessoryRemoving(instance: Instance)
	if not instance:IsA("Accessory") then
		return
	end

	local accessory = instance :: Accessory
	self._pendingAccessories[accessory] = nil

	local accessoryId = self._accessoryIdByInstance[accessory]
	if accessoryId == nil then
		return
	end

	self._accessoryIdByInstance[accessory] = nil
	self:RemoveAccessoryEntries({ accessoryId })
end

function RenderAccessoryService:_ResolveParentRenderId(accessory: Accessory): string?
	local current = accessory.Parent
	while current ~= nil do
		local renderId = _GetRenderIdFromInstance(current)
		if renderId ~= nil then
			return renderId
		end

		current = current.Parent
	end

	return nil
end

function RenderAccessoryService:RegisterAccessoryEntries(entries: { TRenderAccessoryEntry })
	for _, entry in ipairs(entries) do
		self._entriesByAccessoryId[entry.AccessoryId] = entry
	end

	self:_BroadcastAddDeltaForEntries(entries)
end

function RenderAccessoryService:RemoveAccessoryEntries(accessoryIds: { string })
	local removedAccessoryIds = {}
	for _, accessoryId in ipairs(accessoryIds) do
		if self._entriesByAccessoryId[accessoryId] ~= nil then
			self._entriesByAccessoryId[accessoryId] = nil
			table.insert(removedAccessoryIds, accessoryId)
		end
	end

	if #removedAccessoryIds == 0 then
		return
	end

	self:_BroadcastDelta({
		RemovedAccessoryIds = removedAccessoryIds,
	})
end

function RenderAccessoryService:_BuildSortedEntries(): { TRenderAccessoryEntry }
	local entries = {}
	for _, entry in self._entriesByAccessoryId do
		table.insert(entries, entry)
	end

	table.sort(entries, function(left, right)
		return left.AccessoryId < right.AccessoryId
	end)

	return entries
end

function RenderAccessoryService:_BuildBootstrapChunk(
	entries: { TRenderAccessoryEntry },
	chunkIndex: number,
	chunkCount: number,
	startIndex: number,
	endIndex: number
): TRenderAccessoryBootstrapChunk
	local accessoryIdsByIndex = {}
	local accessoryNamesByIndex = {}
	local parentRenderIdsByIndex = {}
	local visualIdsByIndex = {}
	local count = 0

	for entryIndex = startIndex, endIndex do
		local entry = entries[entryIndex]
		if entry ~= nil then
			count += 1
			accessoryIdsByIndex[count] = entry.AccessoryId
			accessoryNamesByIndex[count] = entry.AccessoryName
			parentRenderIdsByIndex[count] = entry.ParentRenderId
			visualIdsByIndex[count] = entry.VisualId
		end
	end

	return {
		ChunkIndex = chunkIndex,
		ChunkCount = chunkCount,
		Count = count,
		AccessoryIdsByIndex = accessoryIdsByIndex,
		AccessoryNamesByIndex = accessoryNamesByIndex,
		ParentRenderIdsByIndex = parentRenderIdsByIndex,
		VisualIdsByIndex = visualIdsByIndex,
	}
end

function RenderAccessoryService:_BroadcastAddDeltaForEntries(entries: { TRenderAccessoryEntry })
	if #entries == 0 then
		return
	end

	table.sort(entries, function(left, right)
		return left.AccessoryId < right.AccessoryId
	end)

	local addedAccessoryIdsByIndex = {}
	local addedAccessoryNamesByIndex = {}
	local addedParentRenderIdsByIndex = {}
	local addedVisualIdsByIndex = {}

	for index, entry in ipairs(entries) do
		addedAccessoryIdsByIndex[index] = entry.AccessoryId
		addedAccessoryNamesByIndex[index] = entry.AccessoryName
		addedParentRenderIdsByIndex[index] = entry.ParentRenderId
		addedVisualIdsByIndex[index] = entry.VisualId
	end

	self:_BroadcastDelta({
		AddedCount = #entries,
		AddedAccessoryIdsByIndex = addedAccessoryIdsByIndex,
		AddedAccessoryNamesByIndex = addedAccessoryNamesByIndex,
		AddedParentRenderIdsByIndex = addedParentRenderIdsByIndex,
		AddedVisualIdsByIndex = addedVisualIdsByIndex,
	})
end

function RenderAccessoryService:_BroadcastDelta(delta: TRenderAccessoryDelta)
	local encodedDelta, serializeError = RenderAccessoryTransportSchema.SerializeDelta(delta)
	if encodedDelta == nil then
		warn(`RenderAccessoryService: failed to serialize delta: {serializeError}`)
		return
	end

	for player in self._hydratedPlayers do
		self._clientSignals.RenderAccessoryDelta:Fire(player, encodedDelta)
	end
end

function RenderAccessoryService:_IsPlayerValid(player: Player): boolean
	return typeof(player) == "Instance"
		and player:IsA("Player")
		and player.Parent == Players
end

return RenderAccessoryService
